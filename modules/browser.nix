{ config, lib, pkgs, settings, ... }:
let
  cfg = config.shanetrs.browser;
  inherit (lib) mkEnableOption mkIf mkMerge mkOption types;
in {
  options.shanetrs.browser = {
    firefox = {
      enable = mkEnableOption "Firefox configuration and integration";
      package = mkOption {
        type = types.package;
        default = pkgs.firefox;
      };
      extensions = mkOption {
        type = types.attrsOf types.str;
        default = {
          "uBlock0@raymondhill.net" = "ublock-origin/latest";
          "addon@darkreader.org" = "darkreader/latest";
          "faststream@andrews" = "faststream/latest";
          "{446900e4-71c2-419f-a6a7-df9c091e268b}" = "bitwarden-password-manager/latest";
        };
      };
      searchEngines = mkOption {
        type = types.attrsOf types.attrs;
        default = {
          "Home Manager" = {
            urls = [{
              template = "https://home-manager-options.extranix.com";
              params = [
                {
                  name = "query";
                  value = "{searchTerms}";
                }
                {
                  name = "release";
                  value = "release-23.11";
                }
              ];
            }];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "!homeopt" "!homeopts" ];
          };
          "MyNixOS" = {
            urls = [{
              template = "https://mynixos.com/search";
              params = [{
                name = "q";
                value = "{searchTerms}";
              }];
            }];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake-white.svg";
            definedAliases = [ "!mynix" "!mynixos" ];
          };
          "NixOS Wiki" = { # Temporary fix
            urls = [{
              template = "https://wiki.nixos.org/w/index.php";
              params = [{
                name = "search";
                value = "{searchTerms}";
              }];
            }];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "!nix" "!nixos" ];
          };
          "NixOS Options" = { # Temporary fix
            urls = [{
              template = "https://search.nixos.org/options";
              params = [{
                name = "query";
                value = "{searchTerms}";
              }];
            }];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "!nixopt" "!nixopts" ];
          };
        };
      };
    };
    chromium = {
      enable = mkEnableOption "Chromium configuration and integration";
      package = mkOption {
        type = types.package;
        default = pkgs.chromium;
      };
      extensions = mkOption {
        type = types.listOf types.str;
        default = [
          "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
          "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
          "kkeakohpadmbldjaiggikmnldlfkdfog" # FastStream Video Player
          "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
        ];
      };
    };

  };

  config = mkMerge [
    (mkIf cfg.firefox.enable {
      home-manager.users.${settings.user}.programs.firefox = {
        enable = true;
        package = cfg.firefox.package;
        profiles.default = {
          search = {
            force = true;
            default = "DuckDuckGo";
            engines = cfg.firefox.searchEngines;
          };
          settings = {
            "widget.use-xdg-desktop-portal.file-picker" = 1;
            "general.autoScroll" = 1;
          };
        };
        policies.ExtensionSettings = builtins.mapAttrs (key: value: {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/${value}.xpi";
          installation_mode = "force_installed"; # Prevents uninstalling without config
        }) cfg.firefox.extensions;
      };
    })

    (mkIf cfg.chromium.enable {
      # TODO: Implement search engines manually
      home-manager.users.${settings.user}.programs.chromium = {
        enable = true;
        extensions = map (id: { inherit id; }) cfg.chromium.extensions;
        package = cfg.chromium.package;
      };
    })
  ];
}
