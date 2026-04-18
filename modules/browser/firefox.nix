{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mapAttrsToList mkEnableOption mkPackageOption mkIf mkOption types;
  inherit (lib.tundra) mergeFormat;
  inherit (builtins) elemAt listToAttrs split;
  cfg = config.shanetrs.browser.firefox;
in {
  options.shanetrs.browser.firefox = {
    enable = mkEnableOption "Firefox configuration and integration";
    package = mkPackageOption pkgs "firefox" {};
    extensions = mkOption {
      type = types.listOf types.str;
      default = [
        "uBlock0@raymondhill.net:ublock-origin/latest"
        "addon@darkreader.org:darkreader/latest"
        "faststream@andrews:faststream/latest"
        "{446900e4-71c2-419f-a6a7-df9c091e268b}:bitwarden-password-manager/latest"
        "sponsorBlocker@ajay.app:sponsorblock/latest"
        (mkIf cfg.pwa.enable "firefoxpwa@filips.si:pwas-for-firefox/latest")
      ];
    };
    pwa = {
      enable = mkEnableOption "Allow installation of 'Progressive Web Apps'";
      package = mkPackageOption pkgs "firefoxpwa" {};
    };
    search = {
      default = mkOption {
        type = types.str;
        default = "ddg";
      };
      engines = mkOption {
        type = types.attrsOf types.attrs;
        default = {
          "Home Manager" = {
            urls = [
              {
                template = "https://home-manager-options.extranix.com";
                params = [
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                  {
                    name = "release";
                    value = "master";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["!homeopt" "!homeopts"];
          };
          "MyNixOS" = {
            urls = [
              {
                template = "https://mynixos.com/search";
                params = [
                  {
                    name = "q";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake-white.svg";
            definedAliases = ["!mynix" "!mynixos"];
          };
          "NixOS Wiki" = {
            urls = [
              {
                template = "https://wiki.nixos.org/w/index.php";
                params = [
                  {
                    name = "search";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["!nix" "!nixos"];
          };
          "NixOS Options" = {
            urls = [
              {
                template = "https://search.nixos.org/options";
                params = [
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                  {
                    name = "channel";
                    value = "unstable";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["!nixopt" "!nixopts"];
          };
          "NixOS Packages" = {
            urls = [
              {
                template = "https://search.nixos.org/packages";
                params = [
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["!nixpkgs"];
          };
          "Nixpkgs Repo" = {
            urls = [
              {
                template = "https://github.com/search";
                params = [
                  {
                    name = "q";
                    value = "repo%3ANixOS%2Fnixpkgs+{searchTerms}";
                  }
                  {
                    name = "type";
                    value = "issues";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["!nixrepo"];
          };
        };
      };
    };
    preferences = mkOption {
      type = types.attrs;
      default = {
        "browser.download.dir" = "${config.tundra.paths.home}/Downloads/Firefox";
        "browser.download.always_ask_before_handling_new_types" = true;
        "browser.shell.checkDefaultBrowser" = false;
        "browser.newtabpage.enabled" = false;
        "browser.urlbar.suggest.quicksuggest.all" = false;
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        "general.autoScroll" = 1;
        "sidebar.revamp" = true;
        "sidebar.verticalTabs" = true;
        "sidebar.visibility" = "expand-on-hover";
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "xpinstall.signatures.required" = false;
      };
    };
    _ = {
      nativeMessagingHosts = mkOption {
        type = types.listOf types.package;
        default = [(mkIf cfg.pwa.enable cfg.pwa.package)];
      };
    };
  };

  config = mkIf cfg.enable {
    shanetrs.desktop.mime = let
      firefoxpwa-mime =
        if cfg.pwa.enable
        then ["firefoxpwa.desktop"]
        else [];
    in {
      default = {
        "application/xhtml+xml" = ["firefox.desktop"];
        "text/html" = ["firefox.desktop"];
      };
      removed = {
        "x-scheme-handler/http" = ["firefox.desktop"] ++ firefoxpwa-mime;
        "x-scheme-handler/https" = ["firefox.desktop"] ++ firefoxpwa-mime;
      };
    };
    tundra = {
      home = {
        ".mozilla/firefox/profiles.ini" = {
          type = "execute";
          source = mergeFormat.ini.plain {
            "Profile0" = {
              IsRelative = 1;
              Name = "default";
              Path = "default";
            };
          };
        };
        ".mozilla/firefox/default/search.json.mozlz4" = {
          type = "execute";
          source = mergeFormat.json.mozlz4 {
            version = 13;
            engines =
              mapAttrsToList (k: v: {
                id = k;
                _name = k;
                _loadPath = "[shanetrs]/browser.firefox.search.engines.\"${k}\"";
                _iconMapObj."16" = "file://${v.icon}";
                _urls = v.urls;
                _definedAliases = v.definedAliases;
              })
              cfg.search.engines;
            metaData = {
              defaultEngineId = cfg.search.default;
              privateDefaultEngineId = cfg.search.default;
              distroID = config.system.nixos.distroId;
              appDefaultEngineId = cfg.search.default;
            };
          };
        };
      };
      packages = mkIf cfg.pwa.enable [cfg.pwa.package];
    };
    systemd.user.tmpfiles.rules = [
      "L ${config.tundra.paths.home}/Downloads/Firefox - - - - /tmp/firefox_${config.tundra.user}"
      "d /tmp/firefox_${config.tundra.user} 1700 ${config.tundra.user} users -"
    ];
    programs.firefox = {
      enable = true;
      inherit (cfg) package preferences;
      nativeMessagingHosts.packages = cfg._.nativeMessagingHosts;
      policies.ExtensionSettings = listToAttrs (map (x: let
          addon = split ":" x;
        in {
          name = elemAt addon 0;
          value = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/${elemAt addon 2}.xpi";
            installation_mode = "force_installed"; # Prevents uninstalling without config
          };
        })
        cfg.extensions);
    };
  };
}
