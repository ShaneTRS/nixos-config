{
  config,
  lib,
  machine,
  pkgs,
  ...
}: let
  inherit (lib) getExe mkEnableOption mkIf mkMerge mkOption types;

  pcfg = config.shanetrs.desktop;
  cfg = pcfg.wm;
  enabled = pcfg.enable && cfg.enable;
in {
  options.shanetrs.desktop.wm = {
    enable = mkEnableOption "Window manager and display manager configuration";
    tty.enable = mkEnableOption "Auto-login on TTY1";
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
    };
  };

  config = mkIf enabled {
    shanetrs.desktop.keymap = let
      launch = cmd: {launch = [(getExe (pkgs.writeShellScriptBin "xremap-launch" cmd))];};

      wpctl = "${pkgs.wireplumber}/bin/wpctl";
      playerctl = getExe pkgs.playerctl;
      brightness = getExe (pkgs.writeShellApplication {
        name = "brightness-8b501";
        runtimeInputs = with pkgs; [brightnessctl procps];
        text = ''
          brightnessctl --class=backlight set "$(( ''${1:-1} * $(pgrep -fc "$0") ))%''${2:-+}"
          sleep 1
        '';
      });
    in {
      keymap = [
        {
          name = "system";
          remap = {
            volumeup = launch "${wpctl} set-volume @DEFAULT_SINK@ 2%+ -l 1.5";
            volumedown = launch "${wpctl} set-volume @DEFAULT_SINK@ 2%- -l 1.5";
            mute = launch "${wpctl} set-mute @DEFAULT_SINK@ toggle";
            micmute = launch "${wpctl} wpctl set-mute @DEFAULT_SOURCE@ toggle";

            playpause = launch "${playerctl} -a play-pause";
            stopcd = launch "${playerctl} -a stop";
            previoussong = launch "${playerctl} -a previous";
            nextsong = launch "${playerctl} -a next";
          };
        }
        {
          name = "system-ungrab";
          remap = {
            brightnessup = launch "${brightness} 1 +";
            brightnessdown = launch "${brightness} 1 -";
          };
        }
        {
          name = "programs";
          remap = {
            super-t = launch "eval \"\${TERMINAL}\"";
            super-d = launch "eval \"\${LAUNCHER}\"";
            super-e = launch "eval \"\${FILE_MANAGER}\"";
            super-shift-s = launch "eval \"\${SCREENSHOT}\"";
          };
        }
      ];
    };
  };

  nixos = mkIf enabled (mkMerge [
    (mkIf cfg.tty.enable {
      systemd.services."getty@tty1" = {
        overrideStrategy = "asDropin";
        serviceConfig.ExecStart = [
          ""
          "${pkgs.util-linux}/sbin/agetty --login-program ${config.services.getty.loginProgram} --autologin ${machine.user} --noclear %I $TERM"
        ];
      };
    })
  ]);

  home = mkIf enabled {
    # todo: replace with standalones
    home = {
      packages = with pkgs;
        cfg.extraPackages
        ++ [
          swaybg # wallpaper
          kdePackages.dolphin # file manager
          kdePackages.konsole # terminal
        ];
      sessionVariables = {
        TERMINAL = "konsole";
        FILE_MANAGER = "dolphin";
        # SCREENSHOT = "";
      };
    };
    services.playerctld.enable = true;
  };
}
