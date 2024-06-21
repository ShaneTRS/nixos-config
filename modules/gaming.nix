{ config, lib, pkgs, ... }:
let
  cfg = config.shanetrs.gaming;
  inherit (lib) mkEnableOption mkIf mkMerge mkOption types;
in {
  options.shanetrs.gaming = {
    epic = {
      enable = mkEnableOption "Epic Games Launcher configuration and installation";
      package = mkOption {
        type = types.package;
        default = pkgs.heroic;
      };
      extraPackages = mkOption {
        type = types.listOf types.package;
        example = with pkgs; [ legendary-gl ];
        default = [ ];
      };
    };
    minecraft = {
      enable = mkEnableOption "Minecraft configuration and installation";
      package = mkOption {
        type = types.package;
        default = pkgs.prismlauncher;
      };
      java = mkOption {
        type = types.package;
        default = pkgs.jre;
      };
      extraPackages = mkOption {
        type = types.listOf types.package;
        example = with pkgs; [ flite ];
        default = [ ];
      };
    };
    steam = {
      enable = mkEnableOption "Steam configuration and installation";
      package = mkOption {
        type = types.package;
        default = pkgs.steam;
      };
      compatibilityTools = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [ proton-ge-bin ];
      };
    };
    gamescope = {
      enable = mkEnableOption "Gamescope configuration and installation";
      package = mkOption {
        type = types.package;
        default = pkgs.gamescope;
      };
      args = mkOption {
        type = types.listOf types.str;
        default = [ "--rt" ];
      };
      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.epic.enable { user.home.packages = [ cfg.epic.package ] ++ cfg.epic.extraPackages; })
    (mkIf cfg.gamescope.enable {
      programs.gamescope = {
        enable = true;
        args = cfg.gamescope.args;
        capSysNice = true;
        env = cfg.gamescope.env;
        package = cfg.gamescope.package;
      };
    })
    (mkIf cfg.minecraft.enable {
      user = {
        programs.java = {
          enable = true;
          package = cfg.minecraft.java;
        };
        home.packages = [ cfg.minecraft.package ] ++ cfg.minecraft.extraPackages;
      };
    })
    (mkIf cfg.steam.enable {
      programs = {
        steam = {
          enable = true;
          remotePlay.openFirewall = true;
          dedicatedServer.openFirewall = true;
          extraCompatPackages = cfg.steam.compatibilityTools;
        };
      };
    })
  ];
}
