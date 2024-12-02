# TODO:
# - Add Nix software center
# - Create update checker, with notifications, and daemon service
# - Figure out support for local secrets
# - Create package that holds Tundra scripts and icons
{ config, lib, pkgs, ... }:
let
  cfg = config.shanetrs.tundra;
  inherit (lib) getExe mkEnableOption mkIf mkMerge mkOption types;
in {
  options.shanetrs.tundra = {
    enable = mkEnableOption "Tundra configuration";
    updates = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      unattended = mkOption {
        type = types.bool;
        default = false;
      };
      checkInterval = mkOption {
        type = types.enum [ "daily" "weekly" "monthly" ];
        default = "daily";
      };
      push = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        credentials = mkOption { type = types.str; };
      };
    };
    appStores = mkOption {
      type = types.listOf (types.enum [ "flatpak" "nix" ]);
      default = [ "flatpak" ];
    };
    # appStore = {
    #   nix = mkOption {
    #     type = types.bool;
    #     default = false;
    #   };
    #   flatpak = mkOption {
    #     type = types.bool;
    #     default = true;
    #   };
    # };
  };

  config = mkIf cfg.enable (mkMerge [
    { environment.systemPackages = with pkgs; [ local.tundra ]; }

    (mkIf cfg.updates.enable {
      systemd = {
        user = {
          services = {
            tundra-notifier = {
              environment = {
                INTERACTIVE = "false";
                UPDATE = "true";
                DISPLAY = ":0";
              };
              script = "${getExe pkgs.local.tundra} notify"; # This is a filler
              serviceConfig.Type = "oneshot";
            };
            tundra-updater = {
              environment = {
                INTERACTIVE = "false";
                UPDATE = "true";
              };
              script = "${getExe pkgs.local.tundra} update";
              serviceConfig.Type = "oneshot";
            };
          };
          timers = {
            tundra-updater = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = let
                  intervals = {
                    "daily" = "*-*-* 04:40:00";
                    "weekly" = "Thu *-*-* 04:40:00";
                    "monthly" = "Thu *-*-1..7 04:40:00";
                  };
                in intervals.${cfg.updates.checkInterval};
                Unit = if cfg.updates.unattended then "tundra-updater.service" else "tundra-notifier.service";
              };
            };
          };
        };
      };
    })

    (mkIf (builtins.elem "nix" cfg.appStores) {
      # TODO: Make this functional
      # environment.systemPackages = with pkgs; [
      #   local.nix-software-center
      # ];
    })

    (mkIf (builtins.elem "flatpak" cfg.appStores) {
      services.flatpak.enable = true;
      environment.systemPackages = with pkgs;
        [ (if config.shanetrs.desktop.session == "plasma" then kdePackages.discover else gnome.gnome-software) ];
    })
  ]);
}
