{ config, lib, functions, pkgs, machine, ... }:
let
  cfg = config.shanetrs.shell // { all_features = cfg.bash.features ++ cfg.zsh.features; };
  inherit (builtins) attrValues elem fromJSON mapAttrs readFile;
  inherit (functions) configs;
  inherit (lib) concatLines mkEnableOption mkIf mkMerge mkOption mkOverride types;
  inherit (lib.strings) optionalString;
  feature-aliases = {
    cat = mkIf (elem "bat" cfg.all_features) "bat";
    ccat = mkIf (elem "bat" cfg.all_features) "command cat";
    ccd = mkIf (elem "zoxide" cfg.all_features) "builtin cd";
    eza = mkIf (elem "eza" cfg.all_features) (mkOverride 99 "eza --header -o");
    f = mkIf (elem "fuck" cfg.all_features) "fuck";
    grep = mkIf (elem "ugrep" cfg.all_features) "ugrep";
    ls = mkIf (elem "eza" cfg.all_features) "eza";
    tree = mkIf (elem "eza" cfg.all_features) "eza -T";
  };
in {
  options.shanetrs.shell = let
    defaults = rec {
      "bash" = {
        aliases = {
          less = "less -R --use-color";
          history-search = if (elem "fzf" cfg.bash.features) then
            ''eval "$(fzf --tac < "$HISTFILE")"''
          else
            ''tac "$HISTFILE" | less'';
        };
        binds = {
          "\\es" = ''
            history-search
          ''; # Alt + S
        };
        extraRc = ''
          nix-run() {
            NIXPKGS_ALLOW_UNFREE=1 nix shell --impure "pkgs#$1" \
              --command sh -c "which ''${1#*.} &>/dev/null && exec ''${1#*.} ''${*:2}; exec ''${*:2}"
          }
          nix-shell() {(
            for i in "$@"; do
              if [ -n "$OPTION" ] || [[ "''${i:0:1}" == "-" ]]; then
                ARGS+=" \"$i\""
                OPTION=1; continue
              fi
              NIX_SHELL_PACKAGES+=" $i";
              ARGS+=" \"pkgs#$i\""
            done
            eval "NIX_SHELL_PACKAGES=\"''${NIX_SHELL_PACKAGES#* }\" NIXPKGS_ALLOW_UNFREE=1 nix shell --impure $ARGS"
          )}
          where() { readlink -f "$(which "$@")"; }
        '';
      };
      "zsh" = {
        aliases.less = bash.aliases.less;
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
        extraRc = bash.extraRc;
      };
    };
    shell-body = shell: {
      enable = mkEnableOption "Customization and base CLI utilities for ${shell}";
      package = mkOption {
        type = types.package;
        default = pkgs.${shell};
        description = "Package to use for the shell";
      };
      aliases = mkOption {
        type = types.attrs;
        default = defaults.${shell}.aliases or { };
        example = { example-alias = "echo hello world!"; };
      };
      binds = mkOption {
        type = types.attrs;
        default = defaults.${shell}.binds or { };
        example = { "\\es" = "history-incremental-search-backward"; };
      };
      features = let
        all-features = [ "bat" "eza" "fd" "fuck" "fastfetch" "fzf" "highlight" "nix-index" "tldr" "ugrep" "zoxide" ];
      in mkOption {
        type = types.listOf (types.enum all-features);
        default = defaults.${shell}.features or all-features;
      };
      extraRc = mkOption {
        type = types.lines;
        default = defaults.${shell}.extraRc or "";
      };
    };
  in {
    default = mkOption {
      type = types.nullOr types.package;
      default = null;
    };
    bash = shell-body "bash";
    zsh = shell-body "zsh";
    doas = {
      enable = mkEnableOption "Customization and setup of doas for privilege escalation";
      noPassCmds = mkOption {
        type = types.listOf types.str;
        default = [ "ionice" "nixos-rebuild" "nix-collect-garbage" "true" ];
      };
      extraRules = mkOption {
        type = types.listOf types.attrs;
        default = [{
          groups = [ "wheel" ];
          keepEnv = true;
          persist = true;
        }];
      };
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
    };
  };

  config = mkMerge [
    {
      users.defaultUserShell = mkIf (cfg.default != null) cfg.default;
      environment.systemPackages = with pkgs;
        [ (mkIf (elem "nix-index" cfg.all_features) nix-index) (mkIf (elem "fuck" cfg.all_features) thefuck) ]
        ++ cfg.extraPackages;
      fonts.packages = mkIf (elem "fastfetch" cfg.all_features) [ (pkgs.nerdfonts.override { fonts = [ "Hack" ]; }) ];
      user = {
        home = {
          packages = with pkgs; [ (mkIf (elem "ugrep" cfg.all_features) ugrep) ];
          sessionVariables = { FZF_COMPLETION_TRIGGER = mkIf (elem "zoxide" cfg.all_features) "#"; };
        };
        programs = {
          bat.enable = mkIf (elem "bat" cfg.all_features) true;
          eza.enable = mkIf (elem "eza" cfg.all_features) true;
          fastfetch = mkIf (elem "fastfetch" cfg.all_features) {
            enable = true;
            package = pkgs.fastfetch.overrideAttrs
              (old: { cmakeFlags = [ "-DENABLE_IMAGEMAGICK7=true" ] ++ old.cmakeFlags or [ ]; });
            settings = let attempt = configs "fastfetch.jsonc";
            in mkIf (attempt != null) (lib.recursiveUpdate (fromJSON (readFile attempt)) {
              logo.source = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            });
          };
          fd = mkIf (elem "fd" cfg.all_features) {
            enable = true;
            hidden = true;
          };
          fzf.enable = mkIf (elem "fzf" cfg.all_features || elem "zoxide" cfg.all_features) true;
          tealdeer = mkIf (elem "tldr" cfg.all_features) {
            enable = true;
            settings.updates.auto_update = true;
          };
          zoxide = mkIf (elem "zoxide" cfg.all_features) {
            enable = true;
            options = [ "--cmd cd" ];
          };
        };
      };
    }

    (mkIf cfg.doas.enable {
      security = {
        sudo.enable = false;
        doas = {
          enable = true;
          extraRules = cfg.doas.extraRules ++ map (cmd: {
            users = [ machine.user ];
            keepEnv = true;
            noPass = true;
            cmd = cmd;
          }) cfg.doas.noPassCmds;
        };
      };
    })

    (mkIf cfg.zsh.enable {
      users.defaultUserShell = mkOverride 999 pkgs.zsh;
      programs.zsh = {
        enable = true;
        autosuggestions.enable = true;
        histSize = 10000; # home-manager default
        promptInit = concatLines (attrValues (mapAttrs (key: value: ''bindkey "${key}" "${value}"'') cfg.zsh.binds) ++ [
          (readFile (configs ".zshrc"))
          (optionalString (elem "fuck" cfg.all_features) ''
            eval "$(thefuck --alias)"
            bindkey -s '\e\e' 'f\n'
            bindkey -s '^[f' 'f\n'
          '')
          (optionalString (elem "nix-index" cfg.all_features) ''
            SGR () { for i in "$@"; do echo -ne "\e[$i"m; done; }
            nix-find() { nix-locate --no-group --top-level -r "$@"; }
            command_not_found_handler() {(
              CMD="$1"; IFS=$'\n'
              if [ "$NIX_MISSING" = "never" ]; then
                echo "$(SGR 1 34)❭❭ $(SGR 0 1)$CMD$(SGR 0) not found! You can use $(SGR 1)nix-find -wtx /$CMD$(SGR 0) to find it" >&2
                exit 127
              fi
              PACKAGES=($(nix-locate --minimal --no-group --type x --type s --top-level --whole-name --at-root "/bin/$CMD"))
              case "''${#PACKAGES}" in
                0) echo "$(SGR 1 34)❭❭ $(SGR 0 1)$CMD$(SGR 0) not found! Are you sure you've typed the command correctly?" >&2 ;;
                1) [ "$NIX_MISSING" = "auto" ] &&
                    exec nix-shell "''${PACKAGES[1]}" --command "$@";
                  echo -n "$(SGR 1 34)❭❭ $(SGR 0 1)$CMD$(SGR 0) not found! Would you like to bring $(SGR 1)''${PACKAGES[1]%.*}$(SGR 0) into scope? " >&2; read
                  exec nix-shell "''${PACKAGES[1]}" --command "$@" ;;
                *) [ "$NIX_MISSING" = "always" ] &&
                    exec nix-shell "''${PACKAGES[1]}" --command "$@";
                  echo "$(SGR 1 34)❭❭ $(SGR 0 1)$CMD$(SGR 0) not found! Would you like to bring one of the following packages into scope?" >&2
                  PS3=""; select PKG in ''${PACKAGES[@]%.*}; do exec nix-shell "$PKG" --command "$@"; done ;;
              esac
              exit 127
            )}
          '')
        ]) + cfg.zsh.extraRc;
      };
      user = { config, ... }: {
        home.packages = with pkgs; [ zsh-completions ];
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
              ignorePatterns = [ "exit" ];
            };
            shellAliases = feature-aliases // cfg.zsh.aliases;
            syntaxHighlighting = mkIf (elem "highlight" cfg.zsh.features) {
              enable = true;
              highlighters = [ "brackets" ];
            };
          };
        };
      };
    })

    (mkIf cfg.bash.enable {
      users.defaultUserShell = mkOverride 999 pkgs.bash;
      user.programs = {
        bash = {
          enable = true;
          historyFile = "$HOME/.config/.bash_history";
          historyControl = [ "erasedups" ];
        };
        fzf.enableBashIntegration = true;
        zoxide.enableBashIntegration = true;
      };
      programs.bash = {
        enableCompletion = true;
        promptInit = concatLines (attrValues (mapAttrs (key: value: "bind '\"${key}\":\"${value}\"'") cfg.bash.binds)
          ++ [
            (readFile (configs ".bashrc"))
            (optionalString (elem "fuck" cfg.all_features) ''eval "$(thefuck --alias)"'')
            (optionalString (elem "nix-index" cfg.all_features) ''
              nix-find() { nix-locate --no-group --top-level -r "$@"; }
            '')
          ]) + cfg.bash.extraRc;
        shellAliases = feature-aliases // cfg.bash.aliases;
      };
    })
  ];
}
