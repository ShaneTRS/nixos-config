use {quote::quote, syn::parse_macro_input};

mod cli {
	use {
		proc_macro2::TokenStream,
		quote::{quote, ToTokens},
		syn::{
			parse::{Parse, ParseStream},
			Expr, Ident, LitStr, Token, Type,
		},
	};

	enum FlagArgument {
		Long(Ident),
		Short(Ident),
	}
	impl Parse for FlagArgument {
		fn parse(input: ParseStream) -> syn::Result<Self> {
			let ident: Ident = input.parse()?;
			Ok(match ident.to_string().len() {
				..3 => Self::Short(ident),
				_ => Self::Long(ident),
			})
		}
	}
	impl ToTokens for FlagArgument {
		fn to_tokens(&self, tokens: &mut TokenStream) {
			match self {
				Self::Long(ident) => {
					let str = ident.to_string().replace('_', "-");
					quote! { concat!("--", #str) }
				}
				Self::Short(ident) => quote! { concat!("-", stringify!(#ident)) },
			}
			.to_tokens(tokens);
		}
	}

	struct FlagHelp {
		typing: LitStr,
		description: LitStr,
	}
	impl Parse for FlagHelp {
		fn parse(input: ParseStream) -> syn::Result<Self> {
			let _: Token![,] = input.parse()?;
			let typing = input.parse()?;
			let description = input.parse()?;

			Ok(Self {
				typing,
				description,
			})
		}
	}

	struct Flag {
		name: Ident,
		switches: Vec<FlagArgument>,
		typing: Type,
		default: Option<Expr>,
		help: Option<FlagHelp>,
	}
	impl Parse for Flag {
		fn parse(input: ParseStream) -> syn::Result<Self> {
			let (switches, name) = {
				let mut switches = Vec::new();
				let mut name = None;
				while !input.peek(Token![,]) {
					let ident = input.parse()?;
					if let FlagArgument::Long(x) = &ident {
						name = Some(x.clone());
					}
					switches.push(ident);
				}
				(
					switches,
					name.ok_or(syn::Error::new(input.span(), "missing flag name"))?,
				)
			};
			let _: Token![,] = input.parse()?;
			let typing = input.parse()?;
			let default = if !input.peek(Token![,]) {
				Some(input.parse()?)
			} else {
				None
			};
			let help = input.parse().ok();
			Ok(Flag {
				name,
				switches,
				typing,
				default,
				help,
			})
		}
	}
	impl Flag {
		fn help(&self) -> TokenStream {
			use shanetrs::ansi::Modifier::{Bold as B, Reset as R};

			let mut short = String::new();
			let mut long = String::new();

			for switch in &self.switches {
				match switch {
					FlagArgument::Short(x) => short = format!("{B}-{x}{R} "),
					FlagArgument::Long(x) => long = format!("{B}--{x}{R} "),
				}
			}

			let (s_formatters, l_formatters) = (
				short.matches('\x1b').count() * 4,
				long.matches('\x1b').count() * 4,
			);

			let (typing, description) =
				self.help
					.as_ref()
					.map_or((String::new(), String::new()), |help| {
						(
							format!("<{}>", help.typing.value()),
							help.description.value(),
						)
					});

			let default_str = match self.default.as_ref() {
				None => quote! {""},
				Some(x) => quote! { format!(" [default: {}]", #x) },
			};

			quote! {
				format!(
					"{short:>pad_s$}{long:<pad_l$}  {typing:<pad_t$}  {description}{default_str}",
					short = #short, long = #long,
					typing = #typing, description = #description, default_str = #default_str,
					pad_s = spacing[0] + #s_formatters, pad_l = spacing[1] + #l_formatters, pad_t = spacing[2],
				),
			}
		}
		fn to_struct_field(&self) -> TokenStream {
			let (name, typing) = (&self.name, &self.typing);
			quote! { #name: Result<#typing, Box<dyn std::error::Error>>, }
		}
		fn to_struct_declare(&self) -> TokenStream {
			let name = &self.name;
			let new = self.default.as_ref().map_or_else(
				|| quote! {Err(format!("{}: cannot be undefined", stringify!(#name)).into())},
				|x| quote! {Ok(#x)},
			);
			quote! { #name: #new, }
		}
	}

	struct Initializer {
		args: Expr,
		spacing: Expr,
	}
	impl Parse for Initializer {
		fn parse(input: ParseStream) -> syn::Result<Self> {
			// let name = input.parse()?;
			// let _: Token![,] = input.parse()?;
			let args = input.parse()?;
			let _: Token![,] = input.parse()?;
			let sizing = input.parse()?;

			Ok(Self {
				args,
				spacing: sizing,
			})
		}
	}

	pub struct CliMacro {
		initializer: Initializer,
		flags: Vec<Flag>,
		help: Vec<TokenStream>,
	}
	impl Parse for CliMacro {
		fn parse(input: ParseStream) -> syn::Result<Self> {
			let mut cli_data = CliMacro {
				help: Vec::new(),
				initializer: input.parse()?,
				flags: Vec::new(),
			};
			let _: Token![;] = input.parse()?;

			while !input.is_empty() {
				if input.peek(LitStr) {
					let lit_str = input.parse::<LitStr>()?;
					cli_data.help.push(quote! { format!(#lit_str), });
				} else {
					let flag: Flag = input.parse()?;
					cli_data.help.push(flag.help());
					cli_data.flags.push(flag);
				}
				let _: Token![;] = input.parse()?;
			}

			Ok(cli_data)
		}
	}
	impl ToTokens for CliMacro {
		fn to_tokens(&self, tokens: &mut TokenStream) {
			let CliMacro {
				initializer,
				flags,
				help,
			} = &self;
			let iter = &initializer.args;
			let spacing = &initializer.spacing;

			let mut iter_body = TokenStream::new();
			let mut struct_fields = TokenStream::new();
			let mut struct_declare = TokenStream::new();

			for flag in flags {
				let Flag {
					name,
					switches,
					typing,
					default,
					help: _,
				} = &flag;
				let false_bool = default
					.as_ref()
					.is_some_and(|x| x.to_token_stream().to_string() == "false");
				for switch in switches {
					iter_body.extend(quote! {
						if let Some(part) = arg.strip_prefix(#switch) {
							let value = if part.is_empty() {
								if #false_bool {
									let peeked = shanetrs_cli_iter.peek().and_then(|x| x.to_string().parse().ok());
									if let Some(peek) = peeked {
										shanetrs_cli_iter.next();
										&peeked.unwrap_or(true).to_string()
									} else {
										&true.to_string()
									}
								} else {
									&shanetrs_cli_iter.next()
										.map(|x| x.to_string()).unwrap_or_default()
								}
							} else { part };
							cli.#name = value.parse::<#typing>().map_err(|e| e.into());
							continue;
						}
					});
				}
				struct_fields.extend(flag.to_struct_field());
				struct_declare.extend(flag.to_struct_declare());
			}

			// struct ResolvedCli {}
			// resolve: Box<dyn Fn() -> ResolvedCli>
			// resolve: Box::new(|| unreachable!())
			// cli.resolve = Box::new(|| ResolvedCli {});

			quote! {{
				struct CliData {
					help_text: String,
					fn_help: Box<dyn Fn() -> bool>,
					fn_unknown: Box<dyn Fn() -> Result<(), Box<dyn std::error::Error>>>,
				}
				struct Cli {
					data: CliData,
					#struct_fields
				};
				let mut cli = Cli {
					data: CliData {
						help_text: String::new(),
						fn_help: Box::new(|| false),
						fn_unknown: Box::new(|| Ok(())),
					},
					#struct_declare
				};

				let mut shanetrs_cli_iter = #iter.peekable();
				let mut shanetrs_cli_help = false;
				let mut shanetrs_cli_unknown = String::new();

				while let Some(arg) = shanetrs_cli_iter.next() {
					if arg == "--help" { shanetrs_cli_help = true; }
					#iter_body
					shanetrs_cli_unknown = arg.to_string();
				};

				cli.data.help_text = {
					let spacing = #spacing;
					[ #( #help )* ].join("\n")
				};
				let closure_help_text = cli.data.help_text.clone();
				cli.data.fn_help = Box::new(move || -> bool {
					if shanetrs_cli_help {
						println!("{}", closure_help_text);
					}
					shanetrs_cli_help
				});
				cli.data.fn_unknown = Box::new(move || -> Result<(), Box<dyn std::error::Error>> {
					if !shanetrs_cli_unknown.is_empty() {
						return Err(format!("cli: unknown flag: {shanetrs_cli_unknown}").into());
					}
					Ok(())
				});

				cli
			}}
			.to_tokens(tokens)
		}
	}
}

#[proc_macro]
pub fn cli(input: proc_macro::TokenStream) -> proc_macro::TokenStream {
	let f = parse_macro_input!(input as cli::CliMacro);
	quote! { #f }.into()
}
