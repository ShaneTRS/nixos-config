{
  config,
  lib,
  pkgs,
  fn,
  ...
}: let
  inherit (builtins) attrNames elem listToAttrs toJSON;
  inherit (fn) configs resolveList;
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
      mods = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        openasar = mkOption {
          type = types.bool;
          default = true;
        };
        provider = mkOption {
          type = types.enum ["equicord" "moonlight" "vencord"];
          default = "equicord";
        };
      };
      package = mkOption {
        type = types.package;
        default = let
          branches = with pkgs; {
            stable = discord;
            canary = discord-canary;
            ptb = discord-ptb;
          };
          m = cfg.discord.mods;
        in (branches.${cfg.discord.branch}.override {
          withOpenASAR = m.enable && m.openasar;
          withEquicord = m.enable && m.provider == "equicord";
          withMoonlight = m.enable && m.provider == "moonlight";
          withVencord = m.enable && m.provider == "vencord";
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
      user.home.packages = [
        (pkgs.symlinkJoin {
          name = "zed-editor-wrapped";
          paths = [cfg.zed-editor.package];
          preferLocalBuild = true;
          nativeBuildInputs = with pkgs; [makeWrapper];
          postBuild = ''
            wrapProgram $out/bin/zeditor \
            --suffix PATH : ${lib.makeBinPath (cfg.zed-editor.extraPackages
              ++ (with pkgs;
                resolveList [
                  gcc
                  clang-tools
                  package-version-server
                  (mkIf (elem "nix" cfg.zed-editor.features) nixd)
                  (mkIf (elem "nix" cfg.zed-editor.features) alejandra)
                  (mkIf (elem "rust" cfg.zed-editor.features) rustup)
                ]))}
          '';
        })
      ];
    })
  ];
}
