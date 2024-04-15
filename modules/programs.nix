{ config, lib, pkgs, functions, ... }:
let
  inherit (lib) mkEnableOption mkIf mkMerge mkOption types;
  cfg = config.shanetrs.programs;
in {
  options.shanetrs.programs = {
    enable = mkEnableOption "Program configuration and integration";
    # TODO: Add a custom binary for running this, that automatically runs it without OpenASAR for the first time
    discord = {
      enable = mkEnableOption "Discord configuration and integration";
      branch = mkOption {
        type = types.enum [ "stable" "canary" "ptb" ];
        default = "canary";
      };
      vencord = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        quickCss = mkOption {
          type = types.str;
          default = "";
        };
        # settings = mkOption {
        #   type = types.attrs;
        #   default = {
        #     useQuickCss = true;
        #     plugins = {
        #       CallTimer.enabled = true;
        #       EmoteCloner.enabled = true;
        #       Experiments.enabled = true;
        #       FakeNitro = {
        #         enabled = true;
        #         transformEmojis = false;
        #         enableStickerBypass = false;
        #       };
        #       ForceOwnerCrown.enabled = true;
        #       MessageLogger.enabled = true;
        #       NoUnblockToJump.enabled = true;
        #       ShowHiddenChannels = {
        #         enabled = true;
        #         showMode = 1;
        #       };
        #       SpotifyCrack.enabled = true;
        #       TypingTweaks.enabled = true;
        #       VolumeBooster = {
        #         enabled = true;
        #         multipler = 2;
        #       };
        #       WhoReacted.enabled = true;
        #       MoreCommands.enabled = true;
        #       NoCanaryMessageLinks.enabled = true;
        #       PlatformIndicators = {
        #         enabled = true;
        #         list = false;
        #         badges = true;
        #       };
        #       GameActivityToggle.enabled = true;
        #       UserVoiceShow.enabled = true;
        #       PermissionsViewer.enabled = true;
        #       Translate.enabled = true;
        #       FixSpotifyEmbeds = {
        #         enabled = true;
        #         volume = 10;
        #       };
        #       DisableCallIdle.enable = true;
        #     };
        #   };
        # };
      };
      openasar.enable = mkOption {
        type = types.bool;
        default = true;
      };
      package = mkOption {
        type = types.package;
        default = let
          branches = with pkgs; {
            stable = discord;
            canary = discord-canary;
            ptb = discord-ptb;
          };
        in (branches.${cfg.discord.branch}.override {
          withOpenASAR = cfg.discord.openasar.enable;
          withVencord = cfg.discord.vencord.enable;
        });
      };
    };
    easyeffects = {
      enable = mkEnableOption "EasyEffects configuration and installation";
      package = mkOption {
        type = types.package;
        default = pkgs.easyeffects;
      };
      # TODO: Add support for adding presets not in the user configs
      # extraPresets = mkOption {
      #   type = types.anything;
      #   default = [ ];
      # };
    };
    vscode = {
      enable = mkEnableOption "VSCode configuration and integration";
      features = mkOption {
        type = types.listOf (types.enum [ "nix" "rust" ]);
        default = [ "nix" "rust" ];
      };
      package = mkOption {
        type = types.package;
        default = pkgs.vscodium;
      };
      extensions = mkOption {
        type = types.listOf types.package;
        default = with pkgs.vscode-extensions;
          [ usernamehw.errorlens tamasfe.even-better-toml ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [{
            name = "codeium";
            publisher = "Codeium";
            version = "1.9.18";
            sha256 = "sha256-a20ALzOKBkgAPN6dyemOVYv1lGRddsdQSI9vwl1uOn0=";
          }];
      };
    };
  };

  config = mkMerge [

    (mkIf cfg.discord.enable {
      user = {
        home.packages = [ cfg.discord.package ];
        xdg.configFile."Vencord/settings/quickCss.css".text = mkIf cfg.discord.vencord.enable
          (builtins.readFile (functions.configs "Vencord/settings/quickCss.css") + "\n" + cfg.discord.vencord.quickCss);
        xdg.configFile."Vencord/settings/settings.json".source =
          mkIf cfg.discord.vencord.enable (functions.configs "Vencord/settings/settings.json");
      };
    })

    (mkIf cfg.easyeffects.enable {
      programs.dconf.enable = true;
      user = {
        home.packages = [ cfg.easyeffects.package ];
        xdg.configFile."easyeffects" = {
          recursive = true;
          source = functions.configs "easyeffects";
        };
      };
    })
    (mkIf cfg.vscode.enable {
      environment.systemPackages = with pkgs; mkIf (builtins.elem "nix" cfg.vscode.features) [ nil nixfmt ];
      user = {
        programs.vscode = {
          enable = true;
          package = cfg.vscode.package;
          extensions = with pkgs.vscode-extensions;
            [
              # (mkIf (builtins.elem "nix" cfg.vscode.features) kamadorueda.alejandra)
              (mkIf (builtins.elem "nix" cfg.vscode.features) jnoortheen.nix-ide)
              (mkIf (builtins.elem "nix" cfg.vscode.features) timonwong.shellcheck)
              (mkIf (builtins.elem "rust" cfg.vscode.features) rust-lang.rust-analyzer)
              (mkIf (builtins.elem "rust" cfg.vscode.features) serayuzgur.crates)
            ] ++ (if (builtins.elem "rust" cfg.vscode.features) then
              pkgs.vscode-utils.extensionsFromVscodeMarketplace [{
                name = "rust-syntax";
                publisher = "dustypomerleau";
                version = "0.6.1";
                sha256 = "sha256-o9iXPhwkimxoJc1dLdaJ8nByLIaJSpGX/nKELC26jGU=";
              }]
            else
              [ ]);
        };
      };
    })
  ];
}
