use {
	shanetrs::{
		ansi::Modifier::{Bold as B, Reset as R, Underline as U},
		smsg, StringDuration,
	},
	std::{
		error::Error,
		fmt, io,
		ops::{Deref, DerefMut},
		str::FromStr,
		sync::{Arc, Mutex},
		time::{Duration, Instant},
	},
	tokio::select,
};

pub async fn main(args: Vec<String>) -> Result<(), Box<dyn Error>> {
	let args = args.into_iter();
	let self_exe = std::env::args().next().unwrap_or_default();

	let cli = strs_pm::cli! { args.clone(), [6, 17, 12];
		"{B}{U}Usage{R}: {self_exe} lazy [ARGUMENTS] {B}--inbound{R} <PORT> {B}--outbound{R} <PORT> {B}--protocol{R} <PROTOCOL> [COMMAND]";

		"\n{B}{U}Required Arguments{R}:";
		inbound  i, u16, "PORT" "Listener port";
		outbound o, u16, "PORT" "Destination port";
		protocol p, Protocol, "PROTOCOL" "Protocols to proxy";
		signal s, i32 0, "SIGNAL" "Signal sent to process after all connections are closed";

		"\n{B}{U}TCP Arguments{R}:";
		timeout, StringDuration "1m".parse::<StringDuration>().unwrap(), "DURATION" "Connection timeout for forwarding";
		retry_interval, StringDuration "200ms".parse::<StringDuration>().unwrap(), "DURATION" "Attempt cooldown";
		min_lifetime, StringDuration "20ms".parse::<StringDuration>().unwrap(), "DURATION" "Minimum connection length for server startup";

		"\n{B}{U}UDP Arguments{R}:";
		mtu, usize 1600, "BYTES" "Maximum packet size";
		blacklist, UdpBlacklist UdpBlacklist::default(), "BLACKLIST" "Socket binding blacklist (comma-separated)";
		keep_alive, StringDuration "30s".parse::<StringDuration>().unwrap(), "DURATION" "Expected UDP keep-alive packet interval";

		"\n{B}{U}Arguments{R}:";
		debug, bool false, "BOOL" "Enable debug logging";
		"      {B}--help{R}                           Print this help message and exit";
		"      [COMMAND]                        Server executable [default: ./start]";
	};

	if (cli.data.fn_help)() {
		return Ok(());
	}
	let exe: Box<str> = match (cli.data.fn_unknown)() {
		Ok(_) => "./start".into(),
		Err(e) => match e.to_string().strip_prefix("cli: unknown flag: ") {
			Some(val) if !val.starts_with('-') => val.into(),
			_ => return Err(e),
		},
	};

	let (
		inbound,
		outbound,
		protocol,
		timeout,
		retry_interval,
		min_lifetime,
		mtu,
		debug,
		keep_alive,
		signal,
	) = (
		cli.inbound?,
		cli.outbound?,
		cli.protocol?,
		cli.timeout?,
		cli.retry_interval?,
		cli.min_lifetime?,
		cli.mtu?,
		cli.debug?,
		cli.keep_alive?,
		cli.signal?,
	);

	let mut blacklist = cli.blacklist?;
	blacklist.deref_mut().push(outbound);

	let activity: Activity = ActivityInner {
		count: 0,
		timestamp: Instant::now() - *keep_alive,
		path: format!("/tmp/lazy.{inbound}").into(),
		keep_alive: *keep_alive,
		signal,
	}
	.into();

	smsg!("Proxying {protocol} connections from {inbound} to {outbound}.");
	let tcp = if protocol.tcp {
		Some(tcp::proxy(
			tcp::ProxySettings {
				inbound,
				outbound,
				timeout: *timeout,
				retry_interval: *retry_interval,
				min_lifetime: *min_lifetime,
				debug,
				exe: exe.clone(),
			},
			activity.clone(),
		))
	} else {
		None
	};
	let udp = if protocol.udp {
		Some(udp::proxy(
			udp::ProxySettings {
				inbound,
				outbound,
				mtu,
				blacklist: blacklist.deref().clone(),
				debug,
				keep_alive: *keep_alive,
				exe,
			},
			activity,
		))
	} else {
		None
	};

	match (tcp, udp) {
		(Some(tcp), Some(udp)) => select! {
			result = tcp => result.map_err(format_err)?,
			result = udp => result.map_err(format_err)?,
		},
		(Some(tcp), None) => tcp.await.map_err(format_err)?,
		(None, Some(udp)) => udp.await.map_err(format_err)?,
		_ => {}
	}

	Ok(())
}

mod tcp {
	use {
		super::{server, Activity},
		shanetrs::dmsg,
		std::{error::Error, net::SocketAddr},
		tokio::{
			io::{copy_bidirectional, Interest, Ready},
			net::{TcpListener, TcpStream},
			task::spawn,
			time::{sleep, timeout, Duration},
		},
	};
	#[derive(Clone)]
	pub struct ProxySettings {
		pub inbound: u16,
		pub outbound: u16,
		pub min_lifetime: Duration,
		pub timeout: Duration,
		pub retry_interval: Duration,
		pub debug: bool,
		pub exe: Box<str>,
	}
	async fn accept(listener: &TcpListener) -> Result<TcpStream, Box<dyn Error>> {
		let (inbound_stream, _) = listener.accept().await?;
		let _ = inbound_stream.set_nodelay(true);
		Ok(inbound_stream)
	}
	async fn client_exists(stream: &TcpStream, wait: Duration) -> bool {
		if wait.is_zero() {
			return true;
		}
		sleep(wait).await;
		!timeout(Duration::ZERO, stream.ready(Interest::READABLE))
			.await
			.unwrap_or(Ok(Ready::EMPTY))
			.unwrap()
			.is_read_closed()
	}
	async fn connect(mut inbound_stream: &mut TcpStream, server: SocketAddr) -> bool {
		if let Ok(mut outbound_stream) = TcpStream::connect(server).await {
			let _ = outbound_stream.set_nodelay(true);
			let _ = copy_bidirectional(&mut inbound_stream, &mut outbound_stream).await;
			return true;
		}
		false
	}
	fn handle(
		mut inbound_stream: TcpStream,
		ProxySettings {
			inbound: _,
			outbound,
			min_lifetime,
			timeout,
			retry_interval,
			debug,
			exe,
		}: ProxySettings,
		activity: Activity,
	) {
		spawn(async move {
			let peer_addr = inbound_stream
				.peer_addr()
				.unwrap_or_else(|_| SocketAddr::from(([0, 0, 0, 0], 0)));
			if !client_exists(&inbound_stream, min_lifetime).await {
				dmsg!(debug, "{peer_addr} disconnected too soon.");
				return;
			}
			activity.add();
			let _ = activity.write();
			dmsg!(debug, "{peer_addr} connected.");
			server::startup(exe.clone());
			for _ in 0..timeout.as_millis() / retry_interval.as_millis() {
				if connect(
					&mut inbound_stream,
					SocketAddr::from(([127, 0, 0, 1], outbound)),
				)
				.await || !client_exists(&inbound_stream, retry_interval).await
				{
					activity.remove();
					let _ = activity.write();
					dmsg!(debug, "{peer_addr} disconnected.");
					server::signal(&activity);
					return;
				}
			}
		});
	}
	pub async fn proxy(settings: ProxySettings, activity: Activity) -> Result<(), Box<dyn Error>> {
		let listener = TcpListener::bind(("0.0.0.0", settings.inbound))
			.await
			.map_err(|e| format!("tcp: bind failed: {}", e.to_string().to_lowercase()))?;
		loop {
			handle(
				accept(&listener)
					.await
					.map_err(|e| format!("tcp: accept failed: {}", e.to_string().to_lowercase()))?,
				settings.clone(),
				activity.clone(),
			);
		}
	}
}

mod udp {
	use {
		super::{format_err, server, Activity},
		shanetrs::dmsg,
		std::{
			collections::hash_map::HashMap, error::Error, net::SocketAddr, sync::Arc,
			time::Duration,
		},
		tokio::{net::UdpSocket, task::spawn, time::sleep},
	};
	#[derive(Clone)]
	pub struct ProxySettings {
		pub inbound: u16,
		pub outbound: u16,
		pub mtu: usize,
		pub blacklist: Vec<u16>,
		pub debug: bool,
		pub keep_alive: Duration,
		pub exe: Box<str>,
	}
	async fn accept(socket: &Arc<UdpSocket>, buffer: &mut [u8]) -> (usize, SocketAddr) {
		socket
			.recv_from(buffer)
			.await
			// This is a silent failure
			.unwrap_or_else(|_| (0, SocketAddr::from(([0, 0, 0, 0], 0))))
	}
	async fn add_entry(
		source: SocketAddr,
		clients: &mut HashMap<SocketAddr, Arc<UdpSocket>>,
		blacklist: &[u16],
		debug: bool,
	) -> Result<Option<Arc<UdpSocket>>, Box<dyn Error>> {
		if clients.contains_key(&source) {
			return Ok(None);
		}
		let socket = listen(0, blacklist, debug).await?;
		clients.insert(source, socket.clone());
		Ok(Some(socket))
	}
	async fn handle(
		inbound_socket: Arc<UdpSocket>,
		clients: &mut HashMap<SocketAddr, Arc<UdpSocket>>,
		ProxySettings {
			inbound: _,
			outbound,
			mtu,
			blacklist,
			debug,
			keep_alive: _,
			exe,
		}: &ProxySettings,
		activity: Activity,
	) -> Result<(), Box<dyn Error>> {
		let mut buffer = vec![0; *mtu];
		let (bytes, source) = accept(&inbound_socket, &mut buffer).await;
		server::startup(exe.clone());
		if let Some(socket) = add_entry(source, clients, blacklist, *debug)
			.await
			.map_err(|e| format!("udp: entry failed: {}", e))?
		{
			dmsg!(*debug, "{source} connected.");
			receive(source, socket, *mtu, inbound_socket.clone()).await;
		}
		activity.ping();
		send(
			clients.get(&source).expect("udp: client is missing?"),
			SocketAddr::from(([127, 0, 0, 1], *outbound)),
			bytes,
			&buffer,
		)
		.await;
		Ok(())
	}
	async fn listen(
		port: u16,
		blacklist: &[u16],
		debug: bool,
	) -> Result<Arc<UdpSocket>, Box<dyn Error>> {
		if port != 0 {
			return Ok(Arc::new(UdpSocket::bind(("0.0.0.0", port)).await.map_err(
				|e| format!("udp: bind failed: {}", e.to_string().to_lowercase()),
			)?));
		}
		let mut socket = None;
		for _ in 0..128 {
			let try_socket = match UdpSocket::bind(("0.0.0.0", 0)).await {
				Ok(s) => s,
				Err(_) => continue,
			};
			let port = &try_socket
				.local_addr()
				.expect("udp: couldn't get port?")
				.port();
			if !blacklist.contains(port) {
				socket = Some(try_socket);
				break;
			}
			dmsg!(debug, "Port {port} is blacklisted. Trying again.");
		}
		match socket {
			Some(s) => Ok(Arc::new(s)),
			None => Err("ran out of attempts".into()),
		}
	}
	pub async fn proxy(settings: ProxySettings, activity: Activity) -> Result<(), Box<dyn Error>> {
		let listener = listen(settings.inbound, &settings.blacklist, settings.debug)
			.await
			.map_err(|e| e.to_string())?;
		let mut clients: HashMap<SocketAddr, Arc<UdpSocket>> = HashMap::new();
		let keep_alive_thread = (settings.keep_alive, activity.clone());
		spawn(async move {
			loop {
				sleep(keep_alive_thread.0).await;
				let _ = keep_alive_thread.1.write();
				server::signal(&keep_alive_thread.1);
			}
		});
		loop {
			if let Err(e) = handle(listener.clone(), &mut clients, &settings, activity.clone())
				.await
				.map_err(format_err)
			{
				dmsg!(settings.debug, "{e}");
			}
		}
	}
	async fn receive(
		client: SocketAddr,
		socket: Arc<UdpSocket>,
		mtu: usize,
		inbound_socket: Arc<UdpSocket>,
	) {
		spawn(async move {
			let mut buffer: Vec<u8> = vec![0; mtu];
			loop {
				let (bytes, _) = accept(&socket, &mut buffer).await;
				send(&inbound_socket, client, bytes, &buffer).await;
			}
		});
	}
	async fn send(socket: &Arc<UdpSocket>, destination: SocketAddr, bytes: usize, buffer: &[u8]) {
		let _ = socket.send_to(&buffer[..bytes], destination).await;
	}
}

fn format_err(e: Box<dyn Error>) -> Box<dyn Error> {
	let err = e.to_string();
	// why, type, message
	let err: Vec<&str> = err.split(": ").collect();
	let err = match *err.get(1).unwrap_or(&err[0]) {
		"cannot be undefined" => format!("Missing argument: {B}{}{R}", err[0]),
		"parse failed" => format!("Could not parse {U}{}{R}: {B}{}{R}", err[0], err[2]),
		"unknown flag" => format!("Unknown argument: {B}{}{R}", err[2]),
		"bind failed" => format!(
			"Failed to open a {U}{}{R} listener: {B}{}{R}",
			err[0].to_uppercase(),
			err[2]
		),
		"accept failed" => format!(
			"Failed to connect over {U}{}{R}: {B}{}{R}",
			err[0].to_uppercase(),
			err[2]
		),
		"entry failed" => format!(
			"Failed to add {U}{}{R} client: {B}{}{R}",
			err[0].to_uppercase(),
			err[2]
		),
		_ => format!("{e}"),
	};
	Box::new(io::Error::new(io::ErrorKind::Other, err))
}

mod server {
	use {
		super::Activity,
		shanetrs::{
			ansi::Modifier::{Bold as B, Reset as R, Underline as U},
			emsg, smsg,
		},
		std::{
			process::{exit, Command},
			time::Instant,
		},
		tokio::spawn,
	};
	static mut STARTUP: u32 = 0;

	pub fn startup(exe: Box<str>) {
		if unsafe { STARTUP } != 0 {
			return;
		};
		smsg!("Connection received. Starting the server.");
		let exe_clone = exe.clone();
		let child = spawn(async move { Command::new(exe_clone.as_ref()).spawn() });
		spawn(async move {
			match child.await.unwrap() {
				Ok(mut child) => {
					unsafe {
						STARTUP = child.id();
					};
					exit(child.wait().unwrap_or_default().code().unwrap_or_default())
				}
				Err(e) => {
					emsg!(
						false,
						"Failed to start {U}{exe}{R}: {B}{}{R}",
						e.to_string().to_lowercase()
					);
				}
			};
		});
	}
	pub fn signal(activity: &Activity) {
		let guard = activity.0.lock().unwrap();
		if guard.signal != 0
			&& guard.count == 0
			&& Instant::now() - guard.timestamp > guard.keep_alive
			&& unsafe { STARTUP } != 0
		{
			let _ = Command::new("kill")
				.args([format!("-{}", guard.signal), unsafe { STARTUP }.to_string()])
				.spawn();
		};
	}
}

#[derive(Clone)]
struct Activity(Arc<Mutex<ActivityInner>>);
impl From<ActivityInner> for Activity {
	fn from(val: ActivityInner) -> Self {
		Activity(Arc::new(Mutex::new(val)))
	}
}
struct ActivityInner {
	count: u16,
	timestamp: Instant,
	path: Box<str>,
	keep_alive: Duration,
	signal: i32,
}
impl Activity {
	fn add(&self) {
		let mut guard = self.0.lock().unwrap();
		guard.count += 1;
	}
	fn remove(&self) {
		let mut guard = self.0.lock().unwrap();
		guard.count = guard.count.saturating_sub(1);
	}
	fn ping(&self) {
		let mut guard = self.0.lock().unwrap();
		guard.timestamp = Instant::now();
	}
	fn write(&self) -> Result<(), std::io::Error> {
		let guard = self.0.lock().unwrap();
		let path = &guard.path.to_string();
		if guard.count != 0 || Instant::now() - guard.timestamp <= guard.keep_alive {
			std::fs::write(path, [])
		} else {
			let _ = std::fs::remove_file(path);
			Ok(())
		}
	}
}

#[derive(Clone, Default, Debug)]
struct Protocol {
	tcp: bool,
	udp: bool,
}
impl fmt::Display for Protocol {
	// TCP, UDP, TCP/UDP
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		let mut protocols = String::new();
		if self.tcp {
			protocols.push_str("TCP")
		}
		if self.udp {
			if self.tcp {
				protocols.push('/')
			}
			protocols.push_str("UDP")
		}
		write!(f, "{protocols}")
	}
}
impl FromStr for Protocol {
	type Err = String;
	/// Parses a string into the [`Protocol`] struct as described [here](#impl-FromStr-for-Protocol)
	fn from_str(s: &str) -> Result<Self, Self::Err> {
		let s = s.to_lowercase();
		if !s.contains("tcp") && !s.contains("udp") {
			return Err("must contain either tcp or udp".to_string());
		}
		Ok(Protocol {
			tcp: s.contains("tcp"),
			udp: s.contains("udp"),
		})
	}
}
#[derive(Clone, Default, Debug)]
struct UdpBlacklist(Vec<u16>);
impl FromStr for UdpBlacklist {
	type Err = String;
	fn from_str(s: &str) -> Result<Self, Self::Err> {
		let s = s.to_lowercase();
		let s = s.trim();
		if s.is_empty() {
			return Ok(UdpBlacklist(vec![]));
		}
		let mut vec = vec![];
		for num in s.split(',') {
			vec.push(num.parse::<u16>().map_err(|e| e.to_string())?);
		}
		Ok(UdpBlacklist(vec))
	}
}
impl fmt::Display for UdpBlacklist {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		write!(f, "{:?}", self.0)
	}
}
impl std::ops::Deref for UdpBlacklist {
	type Target = Vec<u16>;
	fn deref(&self) -> &Self::Target {
		&self.0
	}
}
impl std::ops::DerefMut for UdpBlacklist {
	fn deref_mut(&mut self) -> &mut Self::Target {
		&mut self.0
	}
}
// impl From<UdpBlacklist> for Vec<u16> {
//     fn from(u: UdpBlacklist) -> Self {
//         u.0
//     }
// }
