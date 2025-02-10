use proc_macro2::TokenStream;
use quote::{quote, ToTokens};
use syn::{ext::IdentExt, parse::ParseStream, Token};

#[proc_macro]
pub fn ansi(input: proc_macro::TokenStream) -> proc_macro::TokenStream {
    let inputs = syn::parse_macro_input!(input as AnsiInputs).0;

    let mut body = TokenStream::new();
    for input in inputs {
        match input {
            AnsiInput::Format(vec) => {
                let mut full_tt = TokenStream::new();
                for token in vec {
                    token.to_tokens(&mut full_tt)
                }
                quote!(format!(#full_tt))
            }
            AnsiInput::Tuple(vec) => {
                let mut full_expr = TokenStream::new();
                if vec.len() > 1 {
                    for expr in &vec {
                        quote! {#expr,}.to_tokens(&mut full_expr)
                    }
                    quote!((#full_expr))
                } else {
                    let expr = &vec[0];
                    quote!(#expr)
                }
            }
            AnsiInput::Quick(vec) => {
                let mut full_expr = TokenStream::new();
                for (ident, expr) in &vec {
                    let ident_str = ident.to_string();

                    if !ident_str.starts_with("Fg")
                        && !ident_str.starts_with("Bg")
                        && !ident_str.starts_with("Mod")
                    {
                        continue;
                    }

                    let bits = match (ident_str.chars().nth(3), ident_str.chars().nth(4)) {
                        (Some('8'), _) => quote!(AnsiColorBits::Eight),
                        (Some('2'), Some('4')) => quote!(AnsiColorBits::TwentyFour),
                        _ => quote!(AnsiColorBits::Four),
                    };

                    match (
                        ident_str.chars().next(),
                        ident_str.chars().nth(1),
                        ident_str.chars().nth(2),
                    ) {
                        (Some('F'), Some('g'), _) => quote!(Ansi::Color(#bits, Foreground, #expr)),
                        (Some('B'), Some('g'), _) => quote!(Ansi::Color(#bits, Background, #expr)),
                        (Some('M'), Some('o'), Some('d')) => quote!(Ansi::Mod(#expr)),
                        _ => TokenStream::new(),
                    }
                    .to_tokens(&mut full_expr);

                    if vec.len() > 1 {
                        quote!(,).to_tokens(&mut full_expr)
                    }
                }
                if vec.len() > 1 {
                    quote!((#full_expr))
                } else {
                    quote!(#full_expr)
                }
            }
        }
        .to_tokens(&mut body);
    }

    quote! {{
        use shanetrs::
        {
            Ansi, Ansi::*,
            AnsiMod, AnsiMod::*,
            AnsiColorBits, AnsiColorBits::*,
            AnsiColorMode, AnsiColorMode::*,
            AnsiColor, AnsiColor::*,
        };
        #body
    }}
    .into()
}

struct AnsiInputs(Vec<AnsiInput>);
enum AnsiInput {
    Format(Vec<proc_macro2::TokenTree>),
    Tuple(Vec<syn::Expr>),
    Quick(Vec<(syn::Ident, syn::Expr)>),
}
impl syn::parse::Parse for AnsiInputs {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        let mut vec = Vec::new();
        while !input.is_empty() {
            if input.peek(syn::LitStr) {
                // This is a Format variant
                let mut format_vec = Vec::new();
                while !input.peek(syn::Token![;]) && !input.is_empty() {
                    let tt: proc_macro2::TokenTree = input.parse()?;
                    format_vec.push(tt);
                }
                vec.push(AnsiInput::Format(format_vec));
            } else if input.peek(syn::Ident::peek_any) && !input.peek2(syn::token::Colon) {
                // This is a Quick variant
                let mut quick_vec = Vec::new();
                while !input.peek(syn::Token![;]) && !input.is_empty() {
                    let ident: syn::Ident = input.parse()?;
                    let expr: syn::Expr = input.parse()?;
                    quick_vec.push((ident, expr));
                    if input.peek(syn::Token![,]) {
                        input.parse::<syn::Token![,]>()?;
                    } else {
                        break;
                    }
                }
                vec.push(AnsiInput::Quick(quick_vec));
            } else {
                // This is a Tuple variant
                let mut tuple_vec = Vec::new();
                while !input.peek(syn::Token![;]) && !input.is_empty() {
                    let expr: syn::Expr = input.parse()?;
                    tuple_vec.push(expr);
                    if input.peek(syn::Token![,]) {
                        input.parse::<syn::Token![,]>()?;
                    } else {
                        break;
                    }
                }
                vec.push(AnsiInput::Tuple(tuple_vec));
            }

            input.parse::<syn::Token![;]>()?;
        }
        Ok(Self(vec))
    }
}

#[proc_macro]
pub fn flags(input: proc_macro::TokenStream) -> proc_macro::TokenStream {
    let vec = syn::parse_macro_input!(input as FlagInputs);
    static mut SPACING: [usize; 3] = [0; 3];

    let mut body_pre_decl = TokenStream::new();
    let mut body_decl = TokenStream::new();
    let mut body_help = TokenStream::new();

    for flag in vec.0 {
        match flag {
            FlagInput::Flag {
                long,
                short,
                ty,
                default,
                help_type,
                help_desc,
            } => {
                // Add default bools to false_bools
                match &ty {
                    syn::Type::Path(path) => {
                        let default_value =
                            default.as_ref().map(|v| v.to_token_stream().to_string());
                        if path.path.is_ident("bool") && default_value == Some("false".to_string())
                        {
                            let long = format!("--{}", long.to_string().replace('_', "-"));
                            let short = match &short {
                                Some(short) => {
                                    let short = format!("-{short}");
                                    quote! { false_bools.push(#short.to_string()); }
                                }
                                None => TokenStream::new(),
                            };
                            quote! {
                                false_bools.push(#long.to_string()); #short
                            }
                        } else {
                            TokenStream::new()
                        }
                    }
                    _ => TokenStream::new(),
                }
                .to_tokens(&mut body_pre_decl);

                FlagInput::flag_declare(&long, &short, &ty, &default).to_tokens(&mut body_decl);
                if let Some(help_type) = help_type {
                    let spacing = unsafe { SPACING };
                    FlagInput::flag_help(
                        &long,
                        &short,
                        &help_type,
                        &help_desc.expect("Description is missing?"),
                        &ty,
                        &default,
                        &spacing,
                    )
                    .to_tokens(&mut body_help);
                }
            }
            FlagInput::Help(help) => {
                quote! { println!(#help); }.to_tokens(&mut body_help);
            }
            FlagInput::Init(args, spacing) => {
                quote! { let mut shanetrs_flags_init = #args.peekable(); }
                    .to_tokens(&mut body_pre_decl);
                unsafe { SPACING = spacing };
            }
        }
    }

    quote! {
        let mut false_bools: Vec<String> = Vec::new();
        #body_pre_decl // Default bool pushes, and scope shanetrs_flags_init
        let mut shanetrs_flags = || -> std::collections::HashMap<Box<str>, Box<str>> {
            let mut map = std::collections::HashMap::new();
            while let Some(arg) = shanetrs_flags_init.next() {
                let mut arg_iter = arg.chars();
                if arg_iter.next() == Some('-') {
                    map.remove("_");
                    let (flag, value) = if arg_iter.next() == Some('-') || arg.len() <= 2 {
                        if false_bools.contains(&arg) {
                            let next = shanetrs_flags_init.peek();
                            (
                                arg, if next == Some(&"false".to_string()) || next == Some(&"true".to_string()) {
                                    shanetrs_flags_init.next().unwrap()
                                } else {
                                    "true".to_string()
                                }.into()
                            )
                        } else {
                            (arg, shanetrs_flags_init.next().unwrap_or_default())
                        }
                    } else {
                        let (flag, value) = arg.split_at(2);
                        (flag.to_string(), value.to_string())
                    };
                    map.insert(flag.into(), value.into());
                    continue
                }
                map.insert(Box::from("_"), match map.get("_") {
                    Some(v) => format!("{v} {arg}").into(),
                    None => arg.into(),
                });
            }
            map
        }();
        let flags_help = || {#body_help};
        #body_decl
        #[allow(unused_macros)] macro_rules! flags_help {() => {
            if shanetrs_flags.contains_key("--help") {
                flags_help(); return Ok(())
            }
        }}
        #[allow(unused_macros)] macro_rules! flags_unknown {( $($lit:literal),* ) => {{
            $( shanetrs_flags.remove($lit); )*
            if let Some(key) = shanetrs_flags.iter().next() {
                let key = if key.0.as_ref() == "_" {
                    format!("\'{}\'", key.1)
                } else {
                    key.0.to_string()
                };
                Err(format!("flags: unknown flag: {key}"))
            } else {
                Ok(())
            }
        }}}
    }.into()
}
struct FlagInputs(Vec<FlagInput>);
enum FlagInput {
    Init(syn::Expr, [usize; 3]),
    Help(syn::LitStr),
    Flag {
        long: syn::Ident,
        short: Option<syn::Ident>,
        ty: syn::Type,
        default: Option<syn::Expr>,
        help_type: Option<syn::LitStr>,
        help_desc: Option<syn::LitStr>,
    },
}
impl FlagInput {
    fn flag_declare(
        long: &syn::Ident,
        short: &Option<syn::Ident>,
        ty: &syn::Type,
        default: &Option<syn::Expr>,
    ) -> TokenStream {
        let switch = format!("--{}", long.to_string().replace('_', "-"));
        let (short_get, short_remove) = match short {
            Some(short) => {
                let switch = format!("-{short}");
                (
                    quote! { .or_else(|| shanetrs_flags.get(#switch)) },
                    quote! { shanetrs_flags.remove(#switch) },
                )
            }
            None => (TokenStream::new(), TokenStream::new()),
        };

        let default = match default {
            Some(v) => quote! { Ok(#v) },
            None => quote! { Err(format!("{}: cannot be undefined", stringify!(#long))) },
        };

        quote! {
            let #long: Result<#ty, String> =
            match shanetrs_flags.get(#switch) #short_get {
                Some(v) => v.parse().map_err(|e|
                    format!("{}: parse failed: {e}", stringify!(#long))),
                None => #default,
            };
            shanetrs_flags.remove(#switch); #short_remove;
        }
    }
    fn flag_help(
        long: &syn::Ident,
        short: &Option<syn::Ident>,
        help_type: &syn::LitStr,
        help_desc: &syn::LitStr,
        ty: &syn::Type,
        default: &Option<syn::Expr>,
        spacing: &[usize; 3],
    ) -> TokenStream {
        use shanetrs::AnsiMod::{Bold, Reset};
        let long = format!("{Bold}--{}{Reset}", long.to_string().replace('_', "-"));
        let short = match short {
            Some(short) => format!("{Bold}-{short}{Reset}, "),
            None => String::new(),
        };
        let (default_str, default) = match default {
            Some(default) => (
                " [default: {default}]".to_string(),
                quote! { let default: #ty = #default; },
            ),
            None => (String::new(), TokenStream::new()),
        };

        let formatters: [usize; 2] = [
            short.matches('\x1b').count() * 4,
            long.matches('\x1b').count() * 4,
        ];

        let str_lit = format!(
            "{short:>pad_s$}{long:<pad_l$}  {ty:<pad_t$}  {help_desc}{default_str}",
            pad_s = spacing[0] + formatters[0],
            pad_l = spacing[1] + formatters[1],
            pad_t = spacing[2],
            ty = format!("<{}>", help_type.value()),
            help_desc = help_desc.value()
        );

        quote! { {#default println!(#str_lit)}; }
    }
}
impl syn::parse::Parse for FlagInputs {
    fn parse(input: ParseStream) -> Result<Self, syn::Error> {
        let mut vec = Vec::new();
        let mut init = false;
        while !input.is_empty() {
            // This is a Help variant
            if input.peek(syn::LitStr) {
                let help: syn::LitStr = input.parse()?;
                input.parse::<Token![;]>()?;
                vec.push(FlagInput::Help(help));
                continue;
            }

            // This is an Init variant
            if !init && input.fork().parse::<syn::Ident>()?.to_string().as_str() == "init" {
                init = true;
                input.parse::<syn::Ident>()?;
                input.parse::<Token![,]>()?;
                let args = input.parse::<syn::Expr>()?;
                input.parse::<Token![,]>()?;
                let mut spacing: [usize; 3] = [0; 3];
                for (index, expr) in input
                    .parse::<syn::ExprArray>()?
                    .elems
                    .into_iter()
                    .enumerate()
                {
                    if let syn::Expr::Lit(syn::ExprLit {
                        lit: syn::Lit::Int(i),
                        ..
                    }) = expr
                    {
                        spacing[index] = i.base10_parse()?;
                    }
                }
                input.parse::<Token![;]>()?;
                vec.push(FlagInput::Init(args, spacing));
                continue;
            };

            // This is a Flag variant
            let long = input.parse()?;
            let short = if input.peek(syn::Ident::peek_any) {
                let token: syn::Ident = input.parse()?;
                if token.to_string().len() > 1 {
                    return Err(syn::Error::new(
                        token.span(),
                        "Short flag must a single character",
                    ));
                }
                Some(token)
            } else {
                None
            };

            input.parse::<Token![,]>()?;
            let ty = input.parse()?;
            let default = if !(input.peek(Token![,]) || input.peek(Token![;])) {
                Some(input.parse()?)
            } else {
                None
            };
            let (mut help_type, mut help_desc) = (None, None);
            if input.peek(Token![,]) {
                input.parse::<Token![,]>()?;
                help_type = Some(input.parse()?);
                help_desc = Some(input.parse()?);
            }

            input.parse::<Token![;]>()?;
            vec.push(FlagInput::Flag {
                long,
                short,
                ty,
                default,
                help_type,
                help_desc,
            });
        }
        if !init {
            return Err(syn::Error::new(
                input.span(),
                "flag set must be initialized\nDid you mean `init, Vec<args>, [usize; 3]`?",
            ));
        }
        Ok(FlagInputs(vec))
    }
}
