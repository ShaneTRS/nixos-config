use shanetrs::format_err;
use shanetrs_pm::flags;
fn main() -> Result<(), Box<dyn std::error::Error>> {
    match run(std::env::args().skip(1).collect()) {
        Ok(()) => (),
        Err(e) => {
            let err = e.to_string();
            let err: Vec<&str> = err.split(": ").collect();
            let call_help = matches!(
                *err.get(1).unwrap_or(&err[0]),
                "cannot be undefined" | "parse failed" | "unknown flag"
            );
            if call_help {
                // run(vec!["--help".to_string()])?;
            }
            println!();
            shanetrs::emsg!(false, "{}", format_err(e))
        }
    };
    Ok(())
}

fn run(args: Vec<String>) -> Result<(), Box<dyn std::error::Error>> {
    use shanetrs_pm::ansi;
    // let ansi_single = ansi!(AnsiColor::Red;);

    #[allow(unused_variables)]
    let ansi_string = ansi!(
        "{Header}Sed cursus ante{Reset}:\nLorem ipsum dolor sit amet consectetur adipiscing elit
    [0]{Subtext} Integer nec odio.{Reset} [1]{Subtext} Praesent libero.{Reset}",
        Header = Ansi::Mod(Bold) + Ansi::Mod(Underline),
        Subtext = Ansi::Color(TwentyFour, Foreground, Rgb(170, 170, 170));
    );

    #[allow(unused_variables)]
    let ansi_tuple = ansi!(
        Ansi::Color(Four, Foreground, Rgb(128, 0, 85)) + Ansi::Mod(Underline),
        Ansi::Color(Eight, Foreground, Rgb(128, 0, 85)),
        Ansi::Color(TwentyFour, Foreground, Rgb(128, 0, 85)) + Ansi::Mod(Bold),
        Ansi::Mod(Reset);
    );

    // println!("{}", "20s".parse().unwrap());

    // let ansi_quick = ansi!(
    //     Mod Bold, Mod Underline, Fg4 Blue, Mod Reset;
    // );

    println!("{ansi_string}");
    // println!("\n{0}Say{3} {1}hello{3} {2}world!{3}\n",
    //     ansi_tuple.0, ansi_tuple.1, ansi_tuple.2, ansi_tuple.3);

    use shanetrs::AnsiMod::{Bold, Reset, Underline};
    flags! { init, args.into_iter(), [6, 16, 12];
        "{Bold}{Underline}Usage{Reset}: lazy [ARGUMENTS] {Bold}--inbound{Reset} <PORT> {Bold}--outbound{Reset} <PORT> {Bold}--protocol{Reset} <PROTOCOL> [COMMAND]";
        "\n{Bold}{Underline}Required Arguments{Reset}:";
        inbound  i, u16, "PORT" "Listener port";
        outbound o, u16, "PORT" "Destination port";
        protocol p, String, "PROTOCOL" "Protocols to proxy";
        no_help, bool true;
        "\n{Bold}{Underline}TCP Arguments{Reset}:";
        tcp_timeout, u64 60, "DURATION" "Connection timeout for forwarding";
        retry_interval, u128 200, "DURATION" "Attempt cooldown";
        min_lifetime, u128 20, "DURATION" "Minimum connection length for server startup";
        "\n{Bold}{Underline}UDP Arguments{Reset}:";
        mtu, u16 1600, "BYTES" "Maximum packet size";
        blacklist, u16 0, "BLACKLIST" "Socket binding blacklist (comma-separated)";
        "\n{Bold}{Underline}Arguments{Reset}:";
        debug d, bool false, "BOOL" "Enable debug logging";
        "      {Bold}--help{Reset}                          Print this help message and exit";
        "      [COMMAND]                       Server executable [default: ./start]";
    };

    // Maybe add support for combined toggles for false bool
    // Like -di4888 == --debug --inbound 4888

    // println!("Debug: {debug:?}");

    flags_help!(); // Calls help if --help is passed
    flags_unknown!()?; // Returns error on unknown flag

    let _ = (
        inbound?,
        outbound?,
        protocol?,
        tcp_timeout?,
        no_help?,
        retry_interval?,
        min_lifetime?,
        mtu?,
        blacklist?,
        debug?,
    );

    println!("Survived");
    Ok(())
}
