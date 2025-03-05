{
  config,
  functions,
  lib,
  machine,
  pkgs,
  ...
}: let
  inherit (builtins) attrValues elem fromJSON mapAttrs readFile;
  inherit (lib) concatLines mkEnableOption mkIf mkPackageOption mkMerge mkOption mkOverride optionalString types;
  inherit (functions) configs;

  nixHelpers = import ./_nixHelpers.nix;
  featureAliases = {
    cat = mkIf (elem "bat" cfg._.features) "bat";
    ccat = mkIf (elem "bat" cfg._.features) "command cat";
    ccd = mkIf (elem "zoxide" cfg._.features) "builtin cd";
    eza = mkIf (elem "eza" cfg._.features) (mkOverride 99 "eza --header -o");
    f = mkIf (elem "fuck" cfg._.features) "fuck";
    grep = mkIf (elem "ugrep" cfg._.features) "ugrep";
    ls = mkIf (elem "eza" cfg._.features) "eza";
    tree = mkIf (elem "eza" cfg._.features) "eza -T";
  };

  cfg = config.shanetrs.shell // {_.features = cfg.bash.features ++ cfg.zsh.features;};
in {
  options.shanetrs.shell = let
    shellFeatures = ["bat" "eza" "fd" "fuck" "fastfetch" "fzf" "highlight" "nix-index" "tldr" "ugrep" "zoxide"];
    shellDefaults = rec {
      bash = {
        aliases = {
          less = "less -R --use-color";
          history-search =
            if (elem "fzf" cfg.bash.features)
            then ''eval "$(fzf --tac < "$HISTFILE")"''
            else ''tac "$HISTFILE" | less'';
        };
        binds = {
          "\\es" = "history-search\n"; # alt-s
        };
      };
      zsh = {
        binds = {
          "^[[H" = "beginning-of-line"; # Home
          ";5H" = "beginning-of-line"; # Ctrl + Home
          ";3H" = "beginning-of-line"; # Alt + Home

          "^[[F" = "end-of-line"; # End
          ";5F" = "end-of-line"; # Ctrl + End
          ";3F" = "end-of-line"; # Alt + End

          "^[[2~" = "overwrite-mode"; # Insert

          "^[[3~" = "delete-char"; # Delete
          "5~" = "kill-word"; # Ctrl + Delete
          "3~" = "kill-word"; # Alt + Delete

          ";5C" = "forward-word"; # Ctrl + Right
          ";3C" = "forward-word"; # Alt + Right
          ";5D" = "backward-word"; # Ctrl + Left
          ";3D" = "backward-word"; # Alt + Left

          "^[[5~" = "up-line-or-history"; # Page Up
          "^[[6~" = "down-line-or-history"; # Page Down

          "^[s" = "history-incremental-search-backward"; # Alt + S
        };
        aliases = {inherit (bash.aliases) less;};
      };
    };
    shell = name: {
      enable = mkEnableOption "Custom configuration and tools for ${name}";
      package = mkPackageOption pkgs name {};
      aliases = mkOption {
        type = types.attrs;
        default = shellDefaults.${name}.aliases or {};
      };
      binds = mkOption {
        type = types.attrs;
        default = shellDefaults.${name}.binds or {};
        example = {"\\es" = "history-incremental-search-backward";};
      };
      features = mkOption {
        type = types.listOf (types.enum shellFeatures);
        default = shellDefaults.${name}.features or shellFeatures;
      };
      extraRc = mkOption {
        type = types.lines;
        default = shellDefaults.${name}.extraRc or "";
      };
    };
  in {
    default = mkOption {
      type = types.nullOr types.package;
      default = null;
    };
    bash = shell "bash";
    zsh = shell "zsh";
    doas = {
      enable = mkEnableOption "Custom configuration for doas";
      package = mkPackageOption pkgs "doas" {};
      noPassCmds = mkOption {
        type = types.listOf types.str;
        default = ["ionice" "nixos-rebuild" "nix-collect-garbage" "true"];
      };
      extraRules = mkOption {
        type = types.listOf types.attrs;
        default = [
          {
            groups = ["wheel"];
            keepEnv = true;
            persist = true;
          }
        ];
      };
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
    };
  };

  config = mkMerge [
    {
      users.defaultUserShell = mkIf (cfg.default != null) cfg.default;
      environment.systemPackages = with pkgs;
        cfg.extraPackages
        ++ [
          (mkIf (elem "nix-index" cfg._.features) nix-index)
          (mkIf (elem "fuck" cfg._.features) thefuck)
        ];
      fonts.packages = mkIf (elem "fastfetch" cfg._.features) [pkgs.nerd-fonts.hack];
      user = {
        home = {
          packages = with pkgs; [(mkIf (elem "ugrep" cfg._.features) ugrep)];
          sessionVariables = {
            FZF_COMPLETION_TRIGGER = mkIf (elem "zoxide" cfg._.features) "#";
          };
        };
        programs = {
          bat.enable = mkIf (elem "bat" cfg._.features) true;
          eza.enable = mkIf (elem "eza" cfg._.features) true;
          fastfetch = mkIf (elem "fastfetch" cfg._.features) {
            enable = true;
            package = pkgs.fastfetch.overrideAttrs (old: {
              cmakeFlags = ["-DENABLE_IMAGEMAGICK7=true"] ++ old.cmakeFlags or [];
            });
            settings = let
              attempt = configs "fastfetch.jsonc";
            in
              mkIf (attempt != null) (lib.recursiveUpdate (fromJSON (readFile attempt)) {
                logo.source = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              });
          };
          fd = mkIf (elem "fd" cfg._.features) {
            enable = true;
            hidden = true;
          };
          fzf.enable = mkIf (elem "fzf" cfg._.features || elem "zoxide" cfg._.features) true;
          tealdeer = mkIf (elem "tldr" cfg._.features) {
            enable = true;
            settings.updates.auto_update = true;
          };
          zoxide = mkIf (elem "zoxide" cfg._.features) {
            enable = true;
            options = ["--cmd cd"];
          };
        };
      };
    }

    (mkIf cfg.doas.enable {
      environment.systemPackages = with pkgs; [doas-sudo-shim];
      security = {
        sudo.enable = false;
        doas = {
          enable = true;
          extraRules =
            cfg.doas.extraRules
            ++ map (cmd: {
              users = [machine.user];
              keepEnv = true;
              noPass = true;
              cmd = cmd;
            })
            cfg.doas.noPassCmds;
        };
      };
    })

    (mkIf cfg.bash.enable {
      users.defaultUserShell = mkOverride 999 pkgs.bash;
      programs.bash = {
        enableCompletion = true;
        promptInit =
          concatLines (attrValues
            (mapAttrs (k: v: "bind '\"${k}\":\"${v}\"'") cfg.bash.binds)
            ++ [
              nixHelpers.extraRc
              (readFile (configs ".bashrc"))
              (optionalString (elem "fuck" cfg._.features) ''eval "$(thefuck --alias)"'')
              (optionalString (elem "nix-index" cfg._.features) ''
                nix-find() { ${pkgs.nix-index}/bin/nix-locate --no-group --top-level -r "$@"; }
              '')
            ])
          + cfg.bash.extraRc;
        shellAliases = featureAliases // cfg.bash.aliases;
      };
      user.programs = {
        bash = {
          enable = true;
          historyFile = "$HOME/.config/.bash_history";
          historyControl = ["erasedups"];
        };
        fzf.enableBashIntegration = true;
        zoxide.enableBashIntegration = true;
      };
    })

    (mkIf cfg.zsh.enable {
      users.defaultUserShell = mkOverride 999 pkgs.zsh;
      programs.zsh = {
        enable = true;
        autosuggestions.enable = true;
        histSize = 10000; # home-manager default
        promptInit =
          concatLines (attrValues (mapAttrs (key: value: ''bindkey "${key}" "${value}"'') cfg.zsh.binds)
            ++ [
              nixHelpers.extraRc
              (readFile (configs ".zshrc"))
              (optionalString (elem "fuck" cfg._.features) ''
                eval "$(thefuck --alias)"
                bindkey -s '\e\e' 'f\n'
                bindkey -s '^[f' 'f\n'
              '')
              (optionalString (elem "nix-index" cfg._.features)
                (nixHelpers.nixIndex {inherit pkgs;}))
            ])
          + cfg.zsh.extraRc;
      };
      user = {config, ...}: {
        home.packages = with pkgs; [zsh-completions];
        programs = {
          fzf.enableZshIntegration = true;
          zoxide.enableZshIntegration = true;
          zsh = {
            enable = true;
            package = cfg.zsh.package;
            dotDir = ".config/zsh";
            historySubstringSearch.enable = true;
            history = {
              path = "${config.xdg.configHome}/zsh/zsh_history";
              ignorePatterns = ["exit"];
            };
            shellAliases = featureAliases // cfg.zsh.aliases;
            syntaxHighlighting = mkIf (elem "highlight" cfg.zsh.features) {
              enable = true;
              highlighters = ["brackets"];
            };
          };
        };
      };
    })
  ];
}
