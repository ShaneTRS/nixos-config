mod lazy;
mod silence;
use {
    shanetrs::{
        emsg, format_err,
        AnsiMod::{Bold, Reset},
    },
    std::{env::args, error::Error, io, process::exit},
};

async fn help(bail: bool) {
    lazy::main(vec!["--help".to_string()]).await.unwrap();
    println!();
    silence::main(vec!["--help".to_string()]).unwrap();
    if bail {
        exit(1)
    }
}

#[tokio::main]
async fn main() {
    let mut args = args().skip(1);

    let result: Result<(), Box<dyn Error>> = match args.next().as_deref() {
        Some("silence") => {
            if let Err(e) = silence::main(args.collect()).map_err(format_err) {
                if e.to_string().contains("<help>") {
                    silence::main(vec!["--help".to_string()]).unwrap();
                    println!();
                }
                Err(format_err(e))
            } else {
                Ok(())
            }
        }
        Some("lazy") => {
            if let Err(e) = lazy::main(args.collect()).await.map_err(format_err) {
                if e.to_string().contains("<help>") {
                    lazy::main(vec!["--help".to_string()]).await.unwrap();
                    println!();
                }
                Err(e)
            } else {
                Ok(())
            }
        }
        cmd => {
            let cmd = cmd.unwrap_or_default();
            help(cmd == "--help" || cmd.is_empty()).await;
            Err(Box::new(io::Error::new(
                io::ErrorKind::Other,
                format!("Unknown command: {Bold}{cmd}{Reset}"),
            )))
        }
    };
    if let Err(e) = result {
        emsg!(false, "{e}")
    }
}
