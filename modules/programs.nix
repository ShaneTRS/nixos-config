{
  config,
  lib,
  pkgs,
  fn,
  ...
}: let
  inherit (builtins) attrNames elem listToAttrs toJSON;
  inherit (fn) configs;
  inherit (lib) getExe mkEnableOption mkIf mkMerge mkOption types;
  inherit (pkgs) makeDesktopItem writeShellApplication;
  cfg = config.shanetrs.programs;
in {
  options.shanetrs.programs = {
    enable = mkEnableOption "Program configuration and integration";
    discord = {
      enable = mkEnableOption "Discord configuration and integration";
      branch = mkOption {
        type = types.enum ["stable" "canary" "ptb"];
        default = "canary";
      };
      vencord = {
        enable = mkOption {
          type = types.enum [true false "manual"];
          default = true;
        };
        quickCss = mkOption {
          type = types.str;
          default = ''
            .theme-dark .messagelogger-edited {
              visibility: hidden;
              position: absolute;
            }
            .messagelogger-deleted :is(div, h1, h2, h3, p) {
              visibility: hidden;
              position: absolute;
            }
            svg.vc-trans-icon {
              width: 0;
            }
            .botTag__4211a {
              display: none;
            }
          '';
        };
        plugins = mkOption {
          type = types.attrs;
          default = {
            CallTimer.enabled = true;
            EmoteCloner.enabled = true;
            Experiments.enabled = true;
            FakeNitro = {
              enabled = true;
              transformEmojis = false;
              enableStickerBypass = false;
            };
            ForceOwnerCrown.enabled = true;
            MessageLogger.enabled = true;
            NoUnblockToJump.enabled = true;
            ShowHiddenChannels = {
              enabled = true;
              showMode = 1;
            };
            SpotifyCrack.enabled = true;
            TypingTweaks.enabled = true;
            VolumeBooster = {
              enabled = true;
              multipler = 2;
            };
            WhoReacted.enabled = true;
            MoreCommands.enabled = true;
            NoCanaryMessageLinks.enabled = true;
            PlatformIndicators = {
              enabled = true;
              badges = true;
              list = false;
              messages = false;
            };
            GameActivityToggle.enabled = true;
            UserVoiceShow.enabled = true;
            PermissionsViewer.enabled = true;
            Translate.enabled = true;
            FixSpotifyEmbeds = {
              enabled = true;
              volume = 10;
            };
            DisableCallIdle.enable = true;
          };
        };
        settings = mkOption {
          type = types.attrs;
          default = {
            notifyAboutUpdates = true;
            autoUpdate = true;
            useQuickCss = true;
            themeLinks = [];
            enableReactDevtools = false;
            frameless = false;
            transparent = false;
            winCtrlQ = false;
            plugins = cfg.discord.vencord.plugins;
            winNativeTitleBar = false;
            notifications = {
              timeout = 5000;
              position = "bottom-right";
              useNative = "not-focused";
              logLimit = 50;
            };
            autoUpdateNotification = false;
            macosTranslucency = false;
            disableMinSize = true;
            cloud = {
              authenticated = false;
              url = "https://api.vencord.dev/";
              settingsSync = false;
              settingsSyncVersion = 1711701851176;
            };
            enabledThemes = [];
          };
        };
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
          withVencord = cfg.discord.vencord.enable != false;
        });
      };
    };
    easyeffects = {
      enable = mkEnableOption "EasyEffects configuration and installation";
      package = mkOption {
        type = types.package;
        default = pkgs.easyeffects;
      };
      extraPresets = mkOption {
        type = types.attrs;
        default = {};
      };
    };
    vscode = {
      enable = mkEnableOption "VSCode configuration and integration";
      features = mkOption {
        type = types.listOf (types.enum ["nix" "rust"]);
        default = ["nix" "rust"];
      };
      package = mkOption {
        type = types.package;
        default = pkgs.vscodium;
      };
      extensions = mkOption {
        type = types.listOf types.package;
        default = with pkgs.vscode-extensions;
          [usernamehw.errorlens tamasfe.even-better-toml]
          ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
            {
              name = "codeium";
              publisher = "Codeium";
              version = "1.9.18";
              sha256 = "sha256-a20ALzOKBkgAPN6dyemOVYv1lGRddsdQSI9vwl1uOn0=";
            }
          ];
      };
    };
    zed-editor = {
      enable = mkEnableOption "Zed configuration and integration";
      features = mkOption {
        type = types.listOf (types.enum ["nix" "rust"]);
        default = ["nix" "rust"];
      };
      package = mkOption {
        type = types.package;
        default = pkgs.zed-editor;
      };
      extraPackages = mkOption {
        type = types.listOf types.package;
        default = [];
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.discord.enable {
      user = {
        home.packages = [
          (makeDesktopItem {
            name = "discord";
            desktopName = "Discord";
            exec = getExe (writeShellApplication {
              name = "discord";
              text = ''
                set +o errexit
                pre_exec="$(date +%s)"
                "${getExe cfg.discord.package}"
                [ $(($(date +%s) - pre_exec)) -lt 3 ] && exec "${
                  getExe (cfg.discord.package.override {
                    withOpenASAR = false;
                    withVencord = false;
                  })
                }"
              '';
            });
            terminal = false;
            type = "Application";
            icon = let
              branch = cfg.discord.branch;
            in "${cfg.discord.package}/share/icons/hicolor/256x256/apps/discord${
              if branch == "stable"
              then ""
              else "-${branch}"
            }.png";
          })
        ];
        xdg.configFile = let
          vcfg = cfg.discord.vencord;
        in {
          "Vencord/settings/quickCss.css".text = mkIf (vcfg.enable == true) vcfg.quickCss;
          "Vencord/settings/settings.json".text = mkIf (vcfg.enable == true) (toJSON vcfg.settings);
        };
      };
    })

    (mkIf cfg.easyeffects.enable {
      programs.dconf.enable = true; # settings daemon
      user = {
        home.packages = [cfg.easyeffects.package];
        xdg.configFile =
          {
            "easyeffects" = {
              recursive = true;
              source = configs "easyeffects";
            };
          }
          // listToAttrs (map (k: {
              name = "easyeffects/output/${k}.json";
              value = {text = toJSON cfg.easyeffects.extraPresets.${k};};
            })
            (attrNames cfg.easyeffects.extraPresets));
      };
    })

    (mkIf cfg.vscode.enable {
      user = {
        home.packages = with pkgs; [
          (mkIf (elem "nix" cfg.vscode.features) nixd)
        ];
        programs.vscode = {
          inherit (cfg.vscode) enable package;
          profiles.default.extensions = with pkgs.vscode-extensions;
            [
              # (mkIf (elem "nix" cfg.vscode.features) kamadorueda.alejandra)
              (mkIf (elem "nix" cfg.vscode.features) jnoortheen.nix-ide)
              (mkIf (elem "nix" cfg.vscode.features) timonwong.shellcheck)
              (mkIf (elem "rust" cfg.vscode.features) rust-lang.rust-analyzer)
              (mkIf (elem "rust" cfg.vscode.features) serayuzgur.crates)
            ]
            ++ (
              if (elem "rust" cfg.vscode.features)
              then
                pkgs.vscode-utils.extensionsFromVscodeMarketplace [
                  {
                    name = "rust-syntax";
                    publisher = "dustypomerleau";
                    version = "0.6.1";
                    sha256 = "sha256-o9iXPhwkimxoJc1dLdaJ8nByLIaJSpGX/nKELC26jGU=";
                  }
                ]
              else []
            );
        };
      };
    })

    (mkIf cfg.zed-editor.enable {
      user.programs.zed-editor = {
        inherit (cfg.zed-editor) enable package;
        extraPackages = with pkgs;
          cfg.zed-editor.extraPackages
          ++ [
            (mkIf (elem "nix" cfg.zed-editor.features) nixd)
            (mkIf (elem "nix" cfg.zed-editor.features) nixfmt-classic)
            (mkIf (elem "rust" cfg.zed-editor.features) rust-analyzer)
          ];
      };
    })
  ];
}
