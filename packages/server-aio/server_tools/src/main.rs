mod lazy;
mod silence;
use {
    shanetrs::{
        ansi::Modifier::{Bold as B, Reset as R},
        emsg,
    },
    std::{env::args, error::Error, io, process::exit},
};

fn format_err(e: Box<dyn Error>) -> Box<dyn Error> {
    let err = e.to_string();
    // why, type, message
    let err: Vec<&str> = err.split(": ").collect();
    use shanetrs::ansi::Modifier::{Bold as B, Reset as R, Underline as U};
    let err = match *err.get(1).unwrap_or(&err[0]) {
        "cannot be undefined" => format!("Missing argument: {B}{}{R}<help>", err[0]),
        "parse failed" => format!("Could not parse {U}{}{R}: {B}{}{R}<help>", err[0], err[2]),
        "unknown flag" => format!("Unknown argument: {U}{}{R}<help>", err[2]),
        "help flag" => String::new(),
        _ => format!("{e}"),
    };
    Box::new(io::Error::new(io::ErrorKind::Other, err))
}

async fn help(bail: bool) {
    let _ = lazy::main(vec!["--help".to_string()]).await;
    println!();
    let _ = silence::main(vec!["--help".to_string()]);
    if bail {
        exit(1)
    }
}

#[tokio::main]
async fn main() {
    let mut args = args().skip(1);
    let cmd = args.next();

    let mut result: Result<(), Box<dyn std::error::Error>> = match cmd.as_deref() {
        Some("silence") => silence::main(args.collect()).map_err(format_err),
        Some("lazy") => lazy::main(args.collect()).await.map_err(format_err),
        cmd => {
            let cmd = cmd.unwrap_or_default();
            help(cmd == "--help" || cmd.is_empty()).await;
            Err(Box::new(io::Error::new(
                io::ErrorKind::Other,
                format!("Unknown command: {B}{cmd}{R}"),
            )))
        }
    };
    if let Err(ref e) = result {
        if let Some(rest) = e.to_string().strip_suffix("<help>") {
            let _ = match cmd.as_deref() {
                Some("silence") => silence::main(vec!["--help".to_string()]),
                Some("lazy") => lazy::main(vec!["--help".to_string()]).await,
                _ => Ok(()),
            };
            println!();
            result = Err(format_err(rest.into()));
        }
    }

    if let Err(e) = result {
        emsg!(false, "{e}")
    }
}
