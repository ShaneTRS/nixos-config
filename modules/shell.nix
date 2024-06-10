{ config, lib, functions, pkgs, machine, ... }:
let
  cfg = config.shanetrs.shell // { all_features = cfg.bash.features ++ cfg.zsh.features; };
  inherit (lib) mkEnableOption mkForce mkIf mkMerge mkOption types;
in {
  options.shanetrs.shell = let
    shell-body = shell: {
      enable = mkEnableOption "Customization and base CLI utilities for ${shell}";
      package = mkOption {
        type = types.package;
        default = pkgs.${shell};
        description = "Package to use for the shell";
      };
      aliases = mkOption {
        type = types.attrs;
        default = { };
        example = { example-alias = "echo hello world!"; };
      };
      features = mkOption {
        type = types.listOf (types.enum [ "eza" "zoxide" "ugrep" "highlight" "fastfetch" ]);
        default = [ "eza" "zoxide" "ugrep" "highlight" "fastfetch" ];
      };
      extraRc = mkOption {
        type = types.str;
        default = "";
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
        [
          (mkIf (builtins.elem "fastfetch" cfg.all_features) (fastfetch.overrideAttrs
            (old: { cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DENABLE_IMAGEMAGICK7=true" ]; })))
        ] ++ cfg.extraPackages;
      fonts.packages =
        mkIf (builtins.elem "fastfetch" cfg.all_features) [ (pkgs.nerdfonts.override { fonts = [ "Hack" ]; }) ];
      user = {
        home.packages = with pkgs; [ (mkIf (builtins.elem "ugrep" cfg.all_features) ugrep) ];
        programs = {
          eza.enable = mkIf (builtins.elem "eza" cfg.all_features) true;
          fzf.enable = mkIf (builtins.elem "zoxide" cfg.all_features) true;
          zoxide = mkIf (builtins.elem "zoxide" cfg.all_features) {
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
      programs.zsh = {
        enable = true;
        autosuggestions.enable = true;
        histSize = 10000; # home-manager default
        promptInit = ''
          ${builtins.readFile (functions.configs ".zshrc")}
          ${cfg.zsh.extraRc}
        '';
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
            shellAliases = {
              ccd = mkIf (builtins.elem "zoxide" cfg.zsh.features) "builtin cd";
              eza = mkIf (builtins.elem "eza" cfg.zsh.features) (mkForce "eza --header -o");
              ls = mkIf (builtins.elem "eza" cfg.zsh.features) "eza";
              tree = mkIf (builtins.elem "eza" cfg.zsh.features) "eza -T";
              grep = mkIf (builtins.elem "ugrep" cfg.zsh.features) "ugrep";
              less = "less -R --use-color";
            } // cfg.zsh.aliases;
            syntaxHighlighting = mkIf (builtins.elem "highlight" cfg.zsh.features) {
              enable = true;
              highlighters = [ "brackets" ];
            };
          };
        };
      };
    })

    (mkIf cfg.bash.enable {
      user.programs = {
        bash = {
          enable = true;
          historyFile = ".config/.bash_history";
        };
        fzf.enableBashIntegration = true;
        zoxide.enableBashIntegration = true;
      };
      programs.bash = {
        enableCompletion = true;
        shellInit = ''
          ${builtins.readFile (functions.configs ".bashrc")}
          ${cfg.bash.extraRc}
        '';
        shellAliases = {
          ccd = mkIf (builtins.elem "zoxide" cfg.bash.features) "builtin cd";
          eza = mkIf (builtins.elem "eza" cfg.bash.features) (mkForce "eza --header -o");
          ls = mkIf (builtins.elem "eza" cfg.bash.features) "eza";
          tree = mkIf (builtins.elem "eza" cfg.bash.features) "eza -T";
          grep = mkIf (builtins.elem "ugrep" cfg.bash.features) "ugrep";
          less = "less -R --use-color";
        } // cfg.bash.aliases;
      };
    })
  ];
}
