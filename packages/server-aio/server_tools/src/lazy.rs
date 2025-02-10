use {
    shanetrs::{
        emsg, smsg,
        AnsiMod::{Bold, Reset, Underline},
        StringDuration,
    },
    std::{
        error::Error,
        fmt, io,
        ops::{Deref, DerefMut},
        process::{exit, Command},
        str::FromStr,
    },
    tokio::{select, task::spawn},
};

pub async fn main(args: Vec<String>) -> Result<(), Box<dyn Error>> {
    let self_exe = std::env::args().next().unwrap();
    shanetrs_pm::flags! { init, args.clone().into_iter(), [6, 16, 12];
        "{Bold}{Underline}Usage{Reset}: {self_exe} lazy [ARGUMENTS] {Bold}--inbound{Reset} <PORT> {Bold}--outbound{Reset} <PORT> {Bold}--protocol{Reset} <PROTOCOL> [COMMAND]";

        "\n{Bold}{Underline}Required Arguments{Reset}:";
        inbound  i, u16, "PORT" "Listener port";
        outbound o, u16, "PORT" "Destination port";
        protocol p, Protocol, "PROTOCOL" "Protocols to proxy";

        "\n{Bold}{Underline}TCP Arguments{Reset}:";
        timeout, StringDuration "1m".parse::<StringDuration>().unwrap(), "DURATION" "Connection timeout for forwarding";
        retry_interval, StringDuration "200ms".parse::<StringDuration>().unwrap(), "DURATION" "Attempt cooldown";
        min_lifetime, StringDuration "20ms".parse::<StringDuration>().unwrap(), "DURATION" "Minimum connection length for server startup";

        "\n{Bold}{Underline}UDP Arguments{Reset}:";
        mtu, usize 1600, "BYTES" "Maximum packet size";
        blacklist, UdpBlacklist UdpBlacklist::default(), "BLACKLIST" "Socket binding blacklist (comma-separated)";

        "\n{Bold}{Underline}Arguments{Reset}:";
        debug, bool false, "BOOL" "Enable debug logging";
        "      {Bold}--help{Reset}                          Print this help message and exit";
        "      [COMMAND]                       Server executable [default: ./start]";
    };

    let exe: Box<str> = match shanetrs_flags.get("_") {
        Some(v) => v.clone(),
        None => "./start".into(),
    };
    shanetrs_flags.remove("_");

    // using ↓ instead of flags_help!() to also catch empty args
    if args.contains(&"--help".to_string()) || args.is_empty() {
        flags_help();
        return Ok(());
    };
    drop(self_exe);
    flags_unknown!()?;

    // Unpack all in one go
    let (inbound, outbound, protocol, timeout, retry_interval, min_lifetime, mtu, debug) = (
        inbound?,
        outbound?,
        protocol?,
        timeout?,
        retry_interval?,
        min_lifetime?,
        mtu?,
        debug?,
    );

    let mut blacklist = blacklist?;
    blacklist.deref_mut().push(outbound);
    // println!("{blacklist:?}");

    smsg!("Proxying {protocol} connections from {inbound} to {outbound}.");
    let tcp = if protocol.tcp {
        Some(tcp::proxy(
            inbound,
            outbound,
            *timeout,
            *retry_interval,
            *min_lifetime,
            debug,
            exe.clone(),
        ))
    } else {
        None
    };
    let udp = if protocol.udp {
        Some(udp::proxy(
            inbound,
            outbound,
            mtu,
            blacklist.deref().clone(),
            debug,
            exe.clone(),
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
        super::startup,
        shanetrs::dmsg,
        std::{error::Error, net::SocketAddr},
        tokio::{
            io::{copy_bidirectional, Interest, Ready},
            net::{TcpListener, TcpStream},
            task::spawn,
            time::{sleep, timeout, Duration},
        },
    };
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
            .unwrap_or_else(|_| Ok(Ready::EMPTY))
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
        outbound: u16,
        min_lifetime: Duration,
        timeout: Duration,
        retry_interval: Duration,
        exe: Box<str>,
        debug: bool,
    ) {
        spawn(async move {
            let peer_addr = inbound_stream
                .peer_addr()
                .unwrap_or_else(|_| SocketAddr::from(([0, 0, 0, 0], 0)));
            if !client_exists(&inbound_stream, min_lifetime).await {
                dmsg!(debug, "{peer_addr} disconnected too soon.");
                return;
            }
            dmsg!(debug, "{peer_addr} connected.");
            startup(exe);
            for _ in 0..timeout.as_millis() / retry_interval.as_millis() {
                if connect(
                    &mut inbound_stream,
                    SocketAddr::from(([127, 0, 0, 1], outbound)),
                )
                .await
                    || !client_exists(&inbound_stream, retry_interval).await
                {
                    dmsg!(debug, "{peer_addr} disconnected.");
                    return;
                }
            }
        });
    }
    pub async fn proxy(
        inbound: u16,
        outbound: u16,
        timeout: Duration,
        retry_interval: Duration,
        min_lifetime: Duration,
        debug: bool,
        exe: Box<str>,
    ) -> Result<(), Box<dyn Error>> {
        let listener = TcpListener::bind(("0.0.0.0", inbound))
            .await
            .map_err(|e| format!("tcp: bind failed: {}", e.to_string().to_lowercase()))?;
        loop {
            handle(
                accept(&listener)
                    .await
                    .map_err(|e| format!("tcp: accept failed: {}", e.to_string().to_lowercase()))?,
                outbound,
                min_lifetime,
                timeout,
                retry_interval,
                exe.clone(),
                debug,
            );
        }
    }
}

mod udp {
    use {
        super::{format_err, startup},
        shanetrs::dmsg,
        std::{collections::hash_map::HashMap, error::Error, net::SocketAddr, sync::Arc},
        tokio::{net::UdpSocket, task::spawn},
    };
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
        outbound: u16,
        mtu: usize,
        blacklist: &[u16],
        debug: bool,
        exe: Box<str>,
    ) -> Result<(), Box<dyn Error>> {
        let mut buffer = vec![0; mtu];
        let (bytes, source) = accept(&inbound_socket, &mut buffer).await;
        startup(exe);
        if let Some(socket) = add_entry(source, clients, blacklist, debug)
            .await
            .map_err(|e| format!("udp: entry failed: {}", e))?
        {
            dmsg!(debug, "{source} connected.");
            receive(source, socket, mtu, inbound_socket.clone()).await;
        }
        send(
            clients.get(&source).expect("udp: client is missing?"),
            SocketAddr::from(([127, 0, 0, 1], outbound)),
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
    pub async fn proxy(
        inbound: u16,
        outbound: u16,
        mtu: usize,
        blacklist: Vec<u16>,
        debug: bool,
        exe: Box<str>,
    ) -> Result<(), Box<dyn Error>> {
        let listener = listen(inbound, &blacklist, debug)
            .await
            .map_err(|e| e.to_string())?;
        let mut clients: HashMap<SocketAddr, Arc<UdpSocket>> = HashMap::new();
        loop {
            if let Err(e) = handle(
                listener.clone(),
                &mut clients,
                outbound,
                mtu,
                &blacklist,
                debug,
                exe.clone(),
            )
            .await
            .map_err(format_err)
            {
                dmsg!(debug, "{e}");
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
        "cannot be undefined" => format!("Missing argument: {Bold}{}{Reset}", err[0]),
        "parse failed" => format!(
            "Could not parse {Underline}{}{Reset}: {Bold}{}{Reset}",
            err[0], err[2]
        ),
        "unknown flag" => format!("Unknown argument: {Bold}{}{Reset}", err[2]),
        "bind failed" => format!(
            "Failed to open a {Underline}{}{Reset} listener: {Bold}{}{Reset}",
            err[0].to_uppercase(),
            err[2]
        ),
        "accept failed" => format!(
            "Failed to connect over {Underline}{}{Reset}: {Bold}{}{Reset}",
            err[0].to_uppercase(),
            err[2]
        ),
        "entry failed" => format!(
            "Failed to add {Underline}{}{Reset} client: {Bold}{}{Reset}",
            err[0].to_uppercase(),
            err[2]
        ),
        _ => format!("{e}"),
    };
    Box::new(io::Error::new(io::ErrorKind::Other, err))
}

fn startup(exe: Box<str>) {
    static mut STARTUP: bool = false;
    unsafe {
        STARTUP = if STARTUP { return } else { true };
        smsg!("Connection received. Starting the server.");
        let exe_clone = exe.clone();
        let child = spawn(async move { Command::new(exe_clone.as_ref()).spawn() });
        spawn(async move {
            match child.await.unwrap() {
                Ok(mut child) => exit(child.wait().unwrap_or_default().code().unwrap_or_default()),
                Err(e) => {
                    emsg!(
                        false,
                        "Failed to start {Underline}{exe}{Reset}: {Bold}{}{Reset}",
                        e.to_string().to_lowercase()
                    );
                }
            };
        });
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
        write!(f, "{:?}", self)
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
