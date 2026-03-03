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
    mangohud = {
      enable = mkEnableOption "MangoHud configuration and installation";
      package = mkPackageOption pkgs "mangohud" {};
      settings = mkOption {
        type = types.attrs;
        default = {
          "gpu_temp" = 1;
          "cpu_temp" = 1;
          "graphs" = "vram,ram";
          "frame_timing" = 1;
          "wine" = 1;
          "resolution" = 1;
          "no_display" = 1;
          "font_size" = 19;
          "position" = "top-right";
          "toggle_hud" = "Shift_R+F12";
          "toggle_fps_limit" = "Shift_R+F1";
          "fps_limit" = "64,144";
        };
      };
    };
    minecraft = {
      enable = mkEnableOption "Minecraft configuration and installation";
      package = mkPackageOption pkgs "prismlauncher" {};
      java = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [temurin-jre-bin-25 temurin-jre-bin temurin-jre-bin-8];
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
        default = [];
      };
    };
    vr = {
      enable = mkEnableOption "VR configuration and drivers";
      headsets = mkOption {
        type = types.listOf (types.enum ["quest2"]);
        default = [];
      };
      features = mkOption {
        type = types.listOf (types.enum ["sst" "camera-fbt" "sidequest"]);
        default = ["sst"];
      };
      extraPackages = mkOption {
        type = types.listOf types.package;
        default = [];
      };
    };
  };

  nixos = mkMerge [
    (mkIf cfg.gamescope.enable {
      programs.gamescope = {
        inherit (cfg.gamescope) enable args env package;
        capSysNice = false; # doesn't work in fhs when true
      };
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
      programs.alvr.enable = mkIf (cfg.vr.headsets == "oculus") true; # TODO: declarative configuration
    })
  ];

  home = mkMerge [
    (mkIf cfg.epic.enable {home.packages = cfg.epic.extraPackages ++ [cfg.epic.package];})

    (mkIf cfg.lutris.enable {
      home.packages = [
        (cfg.lutris.package.override {
          extraLibraries = pkgs: cfg.lutris.extraLibraries;
          extraPkgs = pkgs: cfg.lutris.extraPackages;
        })
      ];
    })

    (mkIf cfg.mangohud.enable {
      programs.mangohud = {
        inherit (cfg.mangohud) enable package settings;
      };
    })

    (mkIf cfg.minecraft.enable {
      home.packages =
        cfg.minecraft.extraPackages
        ++ [(cfg.minecraft.package.override {jdks = cfg.minecraft.java;})];
    })

    (mkIf cfg.vr.enable {
      home.packages = with pkgs;
        cfg.vr.extraPackages
        ++ [
          # (mkIf (elem "camera-fbt" cfg.vr.features) shanetrs.camera-fbt)
          (mkIf (elem "sidequest" cfg.vr.features) sidequest)
          # (mkIf (elem "sst" cfg.vr.features) shanetrs.shanetrs-sst)
        ];
    })
  ];
}
