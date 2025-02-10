use {
    shanetrs::{
        dmsg, smsg,
        AnsiMod::{Bold, Reset, Underline},
        StringDuration,
    },
    std::{
        error::Error,
        fs::read_to_string,
        io::{self},
        thread::sleep,
        time::Duration,
    },
};

#[rustfmt::skip]
pub fn main(args: Vec<String>) -> Result<(), Box<dyn Error>> {
    let self_exe = std::env::args().next().unwrap();
    shanetrs_pm::flags! { init, args.into_iter(), [6, 16, 12];
        "{Bold}{Underline}Usage{Reset}: {self_exe} silence [ARGUMENTS]";

        "\n{Bold}{Underline}Arguments{Reset}:";
        length l, StringDuration "5m".parse().unwrap(), "DURATION" "Length of silence";
        interval i, StringDuration "10s".parse().unwrap(), "DURATION" "Interval between checks";
        threshold t, u64 512, "UNITS" "Threshold for silence";
        device d, String "lo".into(), "DEVICE" "Device to monitor";
        stat s, String "rx_bytes".into(), "STATISTIC" "Statistic to monitor";
        debug, bool false, "BOOL" "Enable debug logging";
        "      {Bold}--help{Reset}                          Print this help message and exit";
    };

    flags_help!(); drop(self_exe);
    flags_unknown!()?;

    let (length, interval, threshold, device, stat, debug) =
        (length?, interval?, threshold?, device?, stat?, debug?);

    let mut eta = *length;
    let milestone = (*length / 3).as_secs();
    while eta.as_secs() > 0 {
        if eta.as_secs() % milestone < interval.as_secs() {
            smsg!("Exiting after {} of silence.", StringDuration(eta))
        }
        let difference = get_difference(&device, &stat, *interval)?;
        if difference > threshold {
            dmsg!(debug, "{difference} units transferred. Greater than threshold of {threshold}.");
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
    match read_to_string(format!("/sys/class/net/{}/statistics/{}", device, stat)) {
        Ok(v) => Ok(v.trim().parse::<u64>()?),
        Err(e) => Err(Box::new(io::Error::new(
            io::ErrorKind::Other,
            format!(
                "Failed to check {Underline}{device}.{stat}{Reset}: {Bold}{}{Reset}",
                e.to_string().to_lowercase()
            ),
        ))),
    }
}
