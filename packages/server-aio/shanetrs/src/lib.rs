pub mod ansi {
    use std::fmt;

    #[derive(Copy, Clone)]
    pub enum Sgr<'a> {
        Color(&'a Bits, &'a Mode, &'a Color),
        Modifier(&'a Modifier),
        Raw(&'a str),
    }
    impl fmt::Display for Sgr<'_> {
        fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
            match self {
                Sgr::Color(bits, mode, color) => {
                    use {Bits as B, Mode as M};
                    match bits {
                        B::Four => write!(
                            f,
                            "\x1b[{}m",
                            color.four()
                                + match mode {
                                    M::Foreground => 0,
                                    M::Background => 10,
                                }
                        ),
                        B::Eight => write!(
                            f,
                            "\x1b[{};5;{}m",
                            match mode {
                                M::Foreground => 38,
                                M::Background => 48,
                            },
                            color.eight()
                        ),
                        B::TwentyFour => {
                            let (r, g, b) = color.rgb();
                            write!(f, "\x1b[{};2;{r};{g};{b}m", match mode {
                                M::Foreground => 38,
                                M::Background => 48,
                            })
                        }
                    }
                }
                Sgr::Modifier(modifier) => write!(f, "\x1b[{}m", modifier.code()),
                Sgr::Raw(raw) => write!(f, "\x1b[{raw}m"),
            }
        }
    }

    #[derive(Default, Copy, Clone)]
    pub enum Bits {
        #[default]
        Four,
        Eight,
        TwentyFour,
    }

    #[derive(Default, Copy, Clone)]
    pub enum Mode {
        #[default]
        Foreground,
        Background,
    }

    #[derive(Default, Copy, Clone)]
    pub enum Color {
        Raw(u8),
        Rgb(u8, u8, u8),

        Black,
        Red,
        Green,
        Yellow,
        Blue,
        Purple,
        Cyan,
        #[default]
        White,

        BlackBright,
        RedBright,
        GreenBright,
        YellowBright,
        BlueBright,
        PurpleBright,
        CyanBright,
        WhiteBright,
    }
    impl Color {
        pub fn four(&self) -> u8 {
            use Color as C;
            match self {
                C::Raw(code) => *code,
                C::Rgb(r, g, b) => {
                    let palette = [
                        C::Black,
                        C::Red,
                        C::Green,
                        C::Yellow,
                        C::Blue,
                        C::Purple,
                        C::Cyan,
                        C::White,
                        C::BlackBright,
                        C::RedBright,
                        C::GreenBright,
                        C::YellowBright,
                        C::BlueBright,
                        C::PurpleBright,
                        C::CyanBright,
                        C::WhiteBright,
                    ];

                    let (mut closest, mut shortest) = (0, None);
                    for (i, color) in palette.iter().enumerate() {
                        let (pr, pg, pb) = color.rgb();
                        let distance = (*r as i32 - pr as i32).pow(2)
                            + (*g as i32 - pg as i32).pow(2)
                            + (*b as i32 - pb as i32).pow(2);
                        match shortest {
                            None => {
                                shortest = Some(distance);
                                closest = i;
                            }
                            Some(d) if distance < d => {
                                shortest = Some(distance);
                                closest = i;
                            }
                            _ => continue,
                        }
                    }
                    palette[closest].four()
                }

                C::Black => 30,
                C::Red => 31,
                C::Green => 32,
                C::Yellow => 33,
                C::Blue => 34,
                C::Purple => 35,
                C::Cyan => 36,
                C::White => 37,

                C::BlackBright => 90,
                C::RedBright => 91,
                C::GreenBright => 92,
                C::YellowBright => 93,
                C::BlueBright => 94,
                C::PurpleBright => 95,
                C::CyanBright => 96,
                C::WhiteBright => 97,
            }
        }
        pub fn eight(&self) -> u8 {
            use Color as C;
            match self {
                C::Raw(code) => *code,
                C::Rgb(r, g, b) => 36 * (r / 51) + 6 * (g / 51) + (b / 51) + 16,

                C::Black => 0,
                C::Red => 1,
                C::Green => 2,
                C::Yellow => 3,
                C::Blue => 4,
                C::Purple => 5,
                C::Cyan => 6,
                C::White => 7,

                C::BlackBright => 8,
                C::RedBright => 9,
                C::GreenBright => 10,
                C::YellowBright => 11,
                C::BlueBright => 12,
                C::PurpleBright => 13,
                C::CyanBright => 14,
                C::WhiteBright => 15,
            }
        }
        pub fn rgb(&self) -> (u8, u8, u8) {
            use Color as C;
            match self {
                C::Rgb(r, g, b) => (*r, *g, *b),

                C::Black => (0, 0, 0),
                C::Red => (170, 0, 0),
                C::Green => (0, 170, 0),
                C::Yellow => (170, 170, 0),
                C::Blue => (0, 0, 170),
                C::Purple => (170, 0, 170),
                C::Cyan => (0, 170, 170),
                C::Raw(_) | C::White => (170, 170, 170),

                C::BlackBright => (85, 85, 85),
                C::RedBright => (255, 85, 85),
                C::GreenBright => (85, 255, 85),
                C::YellowBright => (255, 255, 85),
                C::BlueBright => (85, 85, 255),
                C::PurpleBright => (255, 85, 255),
                C::CyanBright => (85, 255, 255),
                C::WhiteBright => (255, 255, 255),
            }
        }
    }
    impl fmt::Display for Color {
        fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
            write!(f, "{}", Sgr::Color(&Bits::Four, &Mode::Foreground, self))
        }
    }

    #[derive(Default, Copy, Clone)]
    pub enum Modifier {
        #[default]
        Reset,
        Bold,
        Dim,
        Italic,
        Invert,
        Conceal,
        Underline,
        DoubleUnderline,
        Overline,
        Strike,
    }
    impl Modifier {
        fn code(&self) -> u8 {
            use Modifier as M;
            match self {
                M::Reset => 0,
                M::Bold => 1,
                M::Dim => 2,
                M::Italic => 3,
                M::Invert => 7,
                M::Conceal => 8,
                M::Underline => 4,
                M::DoubleUnderline => 21,
                M::Overline => 53,
                M::Strike => 9,
            }
        }
    }
    impl fmt::Display for Modifier {
        fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
            write!(f, "{}", Sgr::Modifier(self))
        }
    }
}

use std::{fmt, time::Duration};
#[derive(Clone)]
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
impl std::str::FromStr for StringDuration {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Ok(StringDuration(if let Some(value) = s.strip_suffix("ms") {
            Duration::from_millis(value.parse::<u64>().map_err(|e| e.to_string())?)
        } else if let Some(value) = s.strip_suffix('s') {
            Duration::from_secs(value.parse::<u64>().map_err(|e| e.to_string())?)
        } else if let Some(value) = s.strip_suffix('m') {
            Duration::from_secs(60 * value.parse::<u64>().map_err(|e| e.to_string())?)
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

#[macro_export]
macro_rules! smsg {
    ($($arg:tt)*) => {
        println!("{}[AIO]{} {}", $crate::ansi::Color::Yellow, $crate::ansi::Modifier::Reset, format_args!($($arg)*))
    }
}
#[macro_export]
macro_rules! dmsg {
    ($cond:expr, $($arg:tt)*) => {
        if $cond {println!("{}[AIO]{} {}", $crate::ansi::Color::BlackBright, $crate::ansi::Modifier::Reset, format_args!($($arg)*))}
    }
}
#[macro_export]
macro_rules! emsg {
    ($cond:expr, $($arg:tt)*) => {{
        eprintln!("{}[AIO]{} {}", $crate::ansi::Color::Red, $crate::ansi::Modifier::Reset, format_args!($($arg)*));
        if $cond {
            std::process::exit(1);
        };
    }}
}

// #[cfg(test)]
// mod tests {
//     use super::*;

//     fn add(a: u8, b: u8) -> u8 {
//         a + b
//     }

//     #[test]
//     fn it_works() {
//         let result = add(2, 2);
//         assert_eq!(result, 4);
//     }
// }
