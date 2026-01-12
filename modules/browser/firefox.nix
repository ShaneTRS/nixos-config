{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkPackageOption mkIf mkOption types;
  inherit (builtins) elemAt listToAttrs;

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
    settings = mkOption {
      type = types.attrs;
      default = {
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "general.autoScroll" = 1;
        "sidebar.revamp" = true;
        "sidebar.verticalTabs" = true;
        "sidebar.visibility" = "expand-on-hover";
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
    environment.systemPackages = mkIf cfg.pwa.enable [cfg.pwa.package];
    user.programs.firefox = {
      enable = true;
      package = cfg.package.override {inherit (cfg._) nativeMessagingHosts;};
      profiles.default = {
        search = {
          force = true;
          default = cfg.search.default;
          engines = cfg.search.engines;
        };
        settings = cfg.settings;
      };
      policies.ExtensionSettings = listToAttrs (map (addon: let
          split = lib.splitString ":" addon;
        in {
          name = elemAt split 0;
          value = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/${elemAt split 1}.xpi";
            installation_mode = "force_installed"; # Prevents uninstalling without config
          };
        })
        cfg.extensions);
    };
  };
}
