{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) elem;
  inherit (lib) mkEnableOption mkPackageOption mkOption types mkIf mkMerge;

  cfg = config.shanetrs.gaming;
in {
  options.shanetrs.gaming = {
    epic = {
      enable = mkEnableOption "Epic Games Launcher configuration and installation";
      package = mkPackageOption pkgs "heroic" {};
      extraPackages = mkOption {
        type = types.listOf types.package;
        example = with pkgs; [legendary-gl];
        default = [];
      };
    };
    gamescope = {
      enable = mkEnableOption "Gamescope configuration and installation";
      package = mkPackageOption pkgs "gamescope" {};
      args = mkOption {
        type = types.listOf types.str;
        default = ["--rt"];
      };
      env = mkOption {
        type = types.attrsOf types.str;
        default = {};
      };
    };
    lutris = {
      enable = mkEnableOption "Lutris configuration and installation";
      package = mkPackageOption pkgs "lutris" {};
      extraPackages = mkOption {
        type = types.listOf types.package;
        default = [];
      };
      extraLibraries = mkOption {
        type = types.listOf types.package;
        default = [];
      };
    };
    minecraft = {
      enable = mkEnableOption "Minecraft configuration and installation";
      package = mkPackageOption pkgs "prismlauncher" {};
      java = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [temurin-jre-bin temurin-jre-bin-8];
      };
      extraPackages = mkOption {
        type = types.listOf types.package;
        example = with pkgs; [flite];
        default = [];
      };
    };
    steam = {
      enable = mkEnableOption "Steam configuration and installation";
      package = mkPackageOption pkgs "steam" {};
      protontricks = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        package = mkPackageOption pkgs "protontricks" {};
      };
      extraCompatPackages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [proton-ge-bin];
      };
      extraPackages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [protontricks];
      };
    };
    vr = {
      enable = mkEnableOption "VR configuration and drivers";
      headsets = mkOption {
        type = types.listOf (types.enum ["quest2"]);
        default = [];
      };
      features = mkOption {
        type = types.listOf (types.enum ["wlx-overlay" "sst" "camera-fbt" "sidequest"]);
        default = ["wlx-overlay" "sst"];
      };
      extraPackages = mkOption {
        type = types.listOf types.package;
        default = [];
      };
    };
  };
  config = mkMerge [
    (mkIf cfg.epic.enable {user.home.packages = cfg.epic.extraPackages ++ [cfg.epic.package];})

    (mkIf cfg.gamescope.enable {
      programs.gamescope = {
        enable = true;
        args = cfg.gamescope.args;
        capSysNice = true; # security wrapper
        env = cfg.gamescope.env;
        package = cfg.gamescope.package;
      };
    })

    (mkIf cfg.lutris.enable {
      user.home.packages = [
        (cfg.lutris.package.override {
          extraLibraries = pkgs: cfg.lutris.extraLibraries;
          extraPkgs = pkgs: cfg.lutris.extraPackages;
        })
      ];
    })

    (mkIf cfg.minecraft.enable {
      user.home.packages =
        cfg.minecraft.extraPackages
        ++ [(cfg.minecraft.package.override {jdks = cfg.minecraft.java;})];
    })

    (mkIf cfg.steam.enable {
      programs.steam = {
        inherit (cfg.steam) enable package extraCompatPackages extraPackages;
        remotePlay.openFirewall = true; # 27031..27036
        dedicatedServer.openFirewall = true; # 27015
        protontricks = {inherit (cfg.steam.protontricks) enable package;};
        localNetworkGameTransfers.openFirewall = true; # 27040
      };
    })

    (mkIf cfg.vr.enable {
      user.home.packages = with pkgs;
        cfg.vr.extraPackages
        ++ [
          # (mkIf (elem "camera-fbt" cfg.vr.features) shanetrs.camera-fbt)
          (mkIf (elem "sidequest" cfg.vr.features) sidequest)
          # (mkIf (elem "sst" cfg.vr.features) shanetrs.shanetrs-sst)
          (mkIf (elem "wlx-overlay" cfg.vr.features) shanetrs.wlx-overlay-s)
        ];
      programs.alvr.enable = mkIf (cfg.vr.headsets == "oculus") true; # TODO: declarative configuration
    })
  ];
}
