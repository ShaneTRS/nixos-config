{ config, lib, pkgs, functions, ... }:
let
  cfg = config.shanetrs.gaming;
  inherit (builtins) elem;
  inherit (functions) resolveList;
  inherit (lib) mkEnableOption mkIf mkMerge mkOption optionals types;
in {
  options.shanetrs.gaming = {
    emulation = {
      enable = mkEnableOption "Emulation configuration and installation";
      retroarch = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        package = mkOption {
          type = types.package;
          default = pkgs.retroarch;
        };
        cores = mkOption {
          type = types.listOf types.package;
          default = [ ];
        };
      };
      nintendo = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        "3ds" = {
          enable = mkOption {
            type = types.bool;
            default = cfg.emulation.nintendo.enable;
          };
          package = mkOption {
            type = types.package;
            default = pkgs.libretro.citra;
          };
        };
        ds = {
          enable = mkOption {
            type = types.bool;
            default = cfg.emulation.nintendo.enable;
          };
          package = mkOption {
            type = types.package;
            default = pkgs.libretro.desmume;
          };
        };
        switch = {
          enable = mkOption {
            type = types.bool;
            default = cfg.emulation.nintendo.enable;
          };
          package = mkOption {
            type = types.package;
            default = pkgs.ryujinx;
          };
          extraPackages = mkOption {
            type = types.listOf types.package;
            default = with pkgs; [ local.ryusak ];
          };
        };
        wii = {
          enable = mkOption {
            type = types.bool;
            default = cfg.emulation.nintendo.enable;
          };
          package = mkOption {
            type = types.package;
            default = pkgs.libretro.dolphin;
          };
        };
        wii-u = {
          enable = mkOption {
            type = types.bool;
            default = cfg.emulation.nintendo.enable;
          };
          package = mkOption {
            type = types.package;
            default = pkgs.cemu;
          };
          extraPackages = mkOption {
            type = types.listOf types.package;
            default = with pkgs; [ unstable.evdevhook2 ];
          };
        };
      };
      extraPackages = mkOption {
        type = types.listOf types.package;
        default = [ ];
      };
    };
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
    lutris = {
      enable = mkEnableOption "Lutris configuration and installation";
      package = mkOption {
        type = types.package;
        default = pkgs.lutris;
      };
      extraPackages = mkOption {
        type = types.listOf types.package;
        default = [ ];
      };
      extraLibraries = mkOption {
        type = types.listOf types.package;
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
        type = types.listOf types.package;
        default = with pkgs; [ temurin-jre-bin temurin-jre-bin-8 ];
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
      extraCompatPackages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [ proton-ge-bin ];
      };
      extraPackages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [ protontricks ];
      };
    };
    vr = {
      enable = mkEnableOption "VR configuration and drivers";
      headsets = mkOption {
        type = types.listOf (types.enum [ "quest2" ]);
        default = [ ];
      };
      features = mkOption {
        type = types.listOf (types.enum [ "wlx-overlay" "sst" "camera-fbt" "sidequest" ]);
        default = [ "wlx-overlay" "sst" ];
      };
      extraPackages = mkOption {
        type = types.listOf types.package;
        default = [ ];
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.emulation.enable {
      user.home.packages = let
        e = cfg.emulation;
        n = e.nintendo;
        r = e.retroarch;
      in e.extraPackages ++ optionals n.wii-u.enable n.wii-u.extraPackages
      ++ optionals n.switch.enable n.switch.extraPackages ++ [
        (mkIf r.enable (r.package.override {
          cores = r.cores ++ resolveList [
            (mkIf n.ds.enable n.ds.package)
            (mkIf n."3ds".enable n."3ds".package)
            (mkIf n.wii.enable n.wii.package)
          ];
        }))
        (mkIf n.wii-u.enable n.wii-u.package)
        (mkIf n.switch.enable n.switch.package)
      ];
    })

    (mkIf cfg.epic.enable { user.home.packages = cfg.epic.extraPackages ++ [ cfg.epic.package ]; })

    (mkIf cfg.gamescope.enable {
      programs.gamescope = {
        enable = true;
        args = cfg.gamescope.args;
        capSysNice = true;
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
      user.home.packages = cfg.minecraft.extraPackages
        ++ [ (cfg.minecraft.package.override { jdks = cfg.minecraft.java; }) ];
    })

    (mkIf cfg.steam.enable {
      programs.steam = {
        enable = true;
        package = cfg.steam.package;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        inherit (cfg.steam) extraCompatPackages extraPackages;
      };
    })

    (mkIf cfg.vr.enable {
      user.home.packages = with pkgs;
        cfg.vr.extraPackages ++ [
          # (mkIf (elem "camera-fbt" cfg.vr.features) local.camera-fbt)
          (mkIf (elem "sidequest" cfg.vr.features) sidequest)
          # (mkIf (elem "sst" cfg.vr.features) local.shanetrs-sst)
          (mkIf (elem "wlx-overlay" cfg.vr.features) local.wlx-overlay-s)
        ];
      programs.alvr.enable = mkIf (cfg.vr.headsets == "oculus") true; # TODO: declarative configuration
    })
  ];
}
