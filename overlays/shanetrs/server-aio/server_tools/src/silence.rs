use {
	shanetrs::{
		ansi::Modifier::{Bold as B, Reset as R, Underline as U},
		dmsg, smsg, StringDuration,
	},
	std::{
		error::Error,
		fs::read_to_string,
		io::{self},
		thread::sleep,
		time::Duration,
	},
};

pub fn main(args: Vec<String>) -> Result<(), Box<dyn Error>> {
	let self_exe = std::env::args().next().unwrap();
	let cli = strs_pm::cli! { args.into_iter(), [6, 17, 12];
		"{B}{U}Usage{R}: {self_exe} silence [ARGUMENTS]";
		"\n{B}{U}Arguments{R}:";
		length l, StringDuration "5m".parse::<StringDuration>().unwrap(), "DURATION" "Length of silence";
		interval i, StringDuration "10s".parse::<StringDuration>().unwrap(), "DURATION" "Interval between checks";
		threshold t, u64 512, "UNITS" "Threshold for silence";
		device d, String "lo".to_string(), "DEVICE" "Device to monitor";
		stat s, String "rx_bytes".to_string(), "STATISTIC" "Statistic to monitor";
		debug, bool false, "BOOL" "Enable debug logging";
		"      {B}--help{R}                           Print this help message and exit";
	};

	if (cli.data.fn_help)() {
		return Ok(());
	}
	(cli.data.fn_unknown)()?;

	let (length, interval, threshold, device, stat, debug) = (
		cli.length?,
		cli.interval?,
		cli.threshold?,
		cli.device?,
		cli.stat?,
		cli.debug?,
	);

	let mut eta = *length;
	let milestone = (*length / 3).as_secs();
	while eta.as_secs() > 0 {
		if eta.as_secs() % milestone < interval.as_secs() {
			smsg!("Exiting after {} of silence.", StringDuration(eta))
		}
		let difference = get_difference(&device, &stat, *interval)?;
		if difference > threshold {
			dmsg!(
				debug,
				"{difference} units transferred. Greater than threshold of {threshold}."
			);
			eta = *length;
		}
		eta = eta.checked_sub(*interval).unwrap_or_default();
	}
	smsg!("Silent for {length}, exiting.");

	Ok(())
}

fn get_difference(interface: &str, stat: &str, duration: Duration) -> Result<u64, Box<dyn Error>> {
	let before = get_statistic(interface, stat)?;
	sleep(duration);
	let after = get_statistic(interface, stat)?;
	Ok(after - before)
}

fn get_statistic(device: &str, stat: &str) -> Result<u64, Box<dyn Error>> {
	match read_to_string(format!("/sys/class/net/{device}/statistics/{stat}")) {
		Ok(v) => Ok(v.trim().parse::<u64>()?),
		Err(e) => Err(Box::new(io::Error::new(
			io::ErrorKind::Other,
			format!(
				"Failed to check {U}{device}.{stat}{R}: {B}{}{R}",
				e.to_string().to_lowercase()
			),
		))),
	}
}
