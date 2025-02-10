use std::{fmt, str::FromStr, time::Duration, error::Error, io};

pub fn format_err(e: Box<dyn Error>) -> Box<dyn Error> {
    let err = e.to_string();
    // why, type, message
    let err: Vec<&str> = err.split(": ").collect();
    use AnsiMod::{Bold, Underline, Reset, Conceal};
    let err = match *err.get(1).unwrap_or(&err[0]) {
        "cannot be undefined" => format!("Missing argument: {Bold}{}{Reset}{Conceal}: <help>{Reset}", err[0]),
        "parse failed" => format!("Could not parse {Underline}{}{Reset}: {Bold}{}{Reset}{Conceal}: <help>{Reset}", err[0], err[2]),
        "unknown flag" => format!("Unknown argument: {Underline}{}{Reset}{Conceal}: <help>{Reset}", err[2]),
        _ => format!("{e}"),
    };
    Box::new(io::Error::new(io::ErrorKind::Other, err))
}

#[macro_export] macro_rules! smsg {
    ($($arg:tt)*) => {
        println!("{}[AIO]{} {}", $crate::AnsiColor::Yellow, $crate::AnsiMod::Reset, format_args!($($arg)*))
    }
}
#[macro_export] macro_rules! dmsg {
    ($cond:expr, $($arg:tt)*) => {
        if $cond {println!("{}[AIO]{} {}", $crate::AnsiColor::BlackBright, $crate::AnsiMod::Reset, format_args!($($arg)*))}
    }
}
#[macro_export] macro_rules! emsg {
    ($cond:expr, $($arg:tt)*) => {{
        eprintln!("{}[AIO]{} {}", $crate::AnsiColor::Red, $crate::AnsiMod::Reset, format_args!($($arg)*));
        if $cond {
            std::process::exit(1);
        };
    }}
}

pub enum Ansi {
    Color(AnsiColorBits, AnsiColorMode, AnsiColor),
    Mod(AnsiMod),
    Raw(&'static str)
}
#[derive(Clone, Copy, Default)] pub enum AnsiColor {
    Raw(u8), Rgb(u8, u8, u8),

    Black, Red, Green, Yellow,
    Blue, Purple, Cyan, #[default] White,

    BlackBright, RedBright, GreenBright, YellowBright,
    BlueBright, PurpleBright, CyanBright, WhiteBright,
}
#[derive(Default)] pub enum AnsiColorBits {#[default] Four, Eight, TwentyFour}
#[derive(Default)] pub enum AnsiColorMode {#[default] Foreground, Background}
impl AnsiColor {
    pub fn four(&self) -> u8 {
        use AnsiColor as C;
        match self {
            C::Raw(code) => *code,
            C::Rgb(r, g, b) => {
                let palette = [
                    C::Black, C::Red, C::Green, C::Yellow,
                    C::Blue, C::Purple, C::Cyan, C::White,
                    
                    C::BlackBright, C::RedBright, C::GreenBright, C::YellowBright,
                    C::BlueBright, C::PurpleBright, C::CyanBright, C::WhiteBright
                ];

                let (mut closest, mut shortest) = (0, None);
                for (i, color) in palette.iter().enumerate() {
                    let (pr, pg, pb) = color.rgb();
                    let distance = 
                        (*r as i32 - pr as i32).pow(2) +
                        (*g as i32 - pg as i32).pow(2) +
                        (*b as i32 - pb as i32).pow(2);
                    match shortest {
                        None => {
                            shortest = Some(distance);
                            closest = i;
                        }
                        Some(d) if distance < d => {
                            shortest = Some(distance);
                            closest = i;
                        }
                        _ => continue
                    }
                }
                palette[closest].four()
            }

            C::Black => 30, C::Red => 31, C::Green => 32, C::Yellow => 33,
            C::Blue => 34, C::Purple => 35, C::Cyan => 36, C::White => 37,

            C::BlackBright => 90, C::RedBright => 91, C::GreenBright => 92, C::YellowBright => 93,
            C::BlueBright => 94, C::PurpleBright => 95, C::CyanBright => 96, C::WhiteBright => 97,
        }
    }
    pub fn eight(&self) -> u8 {
        use AnsiColor as C;
        match self {
            C::Raw(code) => *code, C::Rgb(r, g, b) => 36 * (r/51) + 6 * (g/51) + (b/51) + 16,

            C::Black => 0, C::Red => 1, C::Green => 2, C::Yellow => 3,
            C::Blue => 4, C::Purple => 5, C::Cyan => 6, C::White => 7,

            C::BlackBright => 8, C::RedBright => 9, C::GreenBright => 10, C::YellowBright => 11,
            C::BlueBright => 12, C::PurpleBright => 13, C::CyanBright => 14, C::WhiteBright => 15,
        }
    }
    pub fn rgb(&self) -> (u8, u8, u8) {
        use AnsiColor as C;
        match self {
            C::Rgb(r, g, b) => (*r, *g, *b),

            C::Black => (0, 0, 0), C::Red => (170, 0, 0), C::Green => (0, 170, 0), C::Yellow => (170, 170, 0),
            C::Blue => (0, 0, 170), C::Purple => (170, 0, 170), C::Cyan => (0, 170, 170), C::Raw(_) | C::White => (170, 170, 170),

            C::BlackBright => (85, 85, 85), C::RedBright => (255, 85, 85), C::GreenBright => (85, 255, 85), C::YellowBright => (255, 255, 85),
            C::BlueBright => (85, 85, 255), C::PurpleBright => (255, 85, 255), C::CyanBright => (85, 255, 255), C::WhiteBright => (255, 255, 255),
        }
    }
}
#[derive(Copy, Clone, Default)] pub enum AnsiMod {
    #[default] Reset, Bold, Dim, Italic, Invert, Conceal,
    Underline, DoubleUnderline, Overline, Strike,
}
impl AnsiMod {
    pub fn code(&self) -> u8 {
        use AnsiMod as M;
        match self {
            M::Reset => 0, M::Bold => 1, M::Dim => 2, M::Italic => 3, M::Invert => 7, M::Conceal => 8,
            M::Underline => 4, M::DoubleUnderline => 21, M::Overline => 53, M::Strike => 9,
        }
    }
}

pub struct BulkAnsi(pub Vec<Ansi>);
impl std::ops::Deref for BulkAnsi {
    type Target = Vec<Ansi>;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}
impl std::ops::DerefMut for BulkAnsi {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.0
    }
}
impl fmt::Display for BulkAnsi {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.iter().fold(String::new(),
            |accumulator, item| accumulator + item.to_string().as_str()))
    }
}
impl std::ops::Add<Ansi> for Ansi
{
    type Output = BulkAnsi;
    fn add(self, other: Ansi) -> BulkAnsi {
        BulkAnsi(vec![self, other])
    }
}
impl std::ops::Add<Ansi> for BulkAnsi
{
    type Output = BulkAnsi;
    fn add(self, other: Ansi) -> BulkAnsi {
        BulkAnsi(self.0.into_iter().chain(std::iter::once(other)).collect())
    }
}

impl fmt::Display for Ansi {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        use {Ansi as A, AnsiColorMode as M, AnsiColorBits as B};
        match self {
            A::Color(bits, mode, color) => match bits {
                B::Four => write!(f, "\x1b[{}m", match mode { M::Foreground => 0, M::Background => 10 } + color.four()),
                B::Eight => write!(f, "\x1b[{};5;{}m", match mode { M::Foreground => 38, M::Background => 48 }, color.eight()),
                B::TwentyFour => {
                    let (r, g, b) = color.rgb();
                    write!(f, "\x1b[{};2;{r};{g};{b}m", match mode { M::Foreground => 38, M::Background => 48 })
                }
            }
            A::Mod(modifier) => write!(f, "\x1b[{}m", modifier.code()),
            A::Raw(str) => write!(f, "\x1b{str}")
        }
    }
}
impl fmt::Display for AnsiColor {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", Ansi::Color(AnsiColorBits::default(), AnsiColorMode::default(), *self))
    }
}
impl fmt::Display for AnsiMod {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", Ansi::Mod(*self))
    }
}

// #[macro_export] macro_rules! ansi {
//     ($(($($any:tt)*))*) => {vec![$($crate::ansi_helper!($($any)*).to_string(),)*].join("")};
//     ($(($($any:tt)*)),*) => {($($crate::ansi_helper!($($any)*),)*)};
//     ($($any:tt)*) => {$crate::ansi_helper!($($any)*)};
// }
// #[macro_export] macro_rules! ansi_helper {
//     (Mod $mod:ident)  => {$crate::Ansi::Mod($crate::AnsiMod::$mod)};
//     ($color:tt)       => {$crate::ansi_helper!(Color Four Foreground $color)};
//     (Fg4 $color:expr) => {$crate::ansi_helper!(Color Four Foreground $color)};
//     (Bg4 $color:expr) => {$crate::ansi_helper!(Color Four Background $color)};
//     (Fg8 $color:expr) => {$crate::ansi_helper!(Color Eight Foreground $color)};
//     (Bg8 $color:expr) => {$crate::ansi_helper!(Color Eight Background $color)};
//     (Fg24 $color:expr) => {$crate::ansi_helper!(Color TwentyFour Foreground $color)};
//     (Bg24 $color:expr) => {$crate::ansi_helper!(Color TwentyFour Background $color)};
//     (Color $bits:ident $mode:ident $color:expr) => {{
//         use {$crate::AnsiColor::*};
//         $crate::Ansi::Color(
//             $crate::AnsiColorBits::$bits,
//             $crate::AnsiColorMode::$mode,
//             $color
//         )
//     }};
// }

#[derive(Clone, Copy, Default, Debug)]
pub struct StringDuration(pub Duration);
impl std::ops::Deref for StringDuration {
    type Target = Duration;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}
impl std::ops::DerefMut for StringDuration {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.0
    }
}
impl FromStr for StringDuration {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let s = s.to_lowercase();
        let s = s.trim();
        Ok(StringDuration(if s.ends_with("ms") {
            Duration::from_millis(
                s[0..s.len() - 2]
                    .parse::<u64>()
                    .map_err(|e| e.to_string())?,
            )
        } else if s.ends_with('s') {
            Duration::from_secs(
                s[0..s.len() - 1]
                    .parse::<u64>()
                    .map_err(|e| e.to_string())?,
            )
        } else if s.ends_with('m') {
            Duration::from_secs(
                s[0..s.len() - 1]
                    .parse::<u64>()
                    .map_err(|e| e.to_string())?
                    * 60,
            )
        } else {
            Err("invalid format. use ms, s, or m".to_string())?
        }))
    }
}
impl fmt::Display for StringDuration {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let m = self.as_millis();
        if m % 60000 == 0 {
            write!(f, "{}m", self.as_secs() / 60)
        } else if m % 1000 == 0 {
            write!(f, "{}s", self.as_secs())
        } else {
            write!(f, "{}ms", self.as_millis())
        }
    }
}