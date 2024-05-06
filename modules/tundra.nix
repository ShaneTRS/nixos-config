# TODO:
# - Add Nix software center
# - Create update checker, with notifications, and daemon service
# - Figure out push credentials and merging
# - Figure out support for local secrets
# - Create package that holds Tundra scripts and icons

{ config, lib, pkgs, ... }:
let
  cfg = config.shanetrs.tundra;
  inherit (lib) mkEnableOption mkIf mkMerge mkOption types;
in {
  options.shanetrs.tundra = {
    enable = mkEnableOption "Tundra configuration";
    updates = {
      enable = mkOption {
        type = types.bool;
        default = true;
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

    (mkIf (builtins.elem "nix" cfg.appStores) {
      # TODO: Make this functional
      # environment.systemPackages = with pkgs; [
      #   local.nix-software-center
      # ];
    })

    (mkIf (builtins.elem "flatpak" cfg.appStores) {
      services.flatpak.enable = true;
      environment.systemPackages = with pkgs;
        [ (if config.shanetrs.desktop.session == "plasma" then libsForQt5.discover else gnome.gnome-software) ];
    })
  ]);
}
