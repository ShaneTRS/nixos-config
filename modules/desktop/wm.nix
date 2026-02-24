{
  config,
  lib,
  pkgs,
  machine,
  ...
}: let
  inherit (lib) getExe mkIf mkMerge;
  cfg = config.shanetrs.desktop;
in {
  config = mkIf cfg.enable (mkMerge [
    (mkIf (cfg.session == "wm") {
      # todo: replace with standalones
      user = {
        home = {
          packages = with pkgs; [
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
    })

    (let
      xdgPortalConf = {
        extraPortals = [pkgs.xdg-desktop-portal-gnome];
        configPackages = [pkgs.niri];
        config.niri = {
          "org.freedesktop.impl.portal.FileChooser" = "gtk";
        };
      };
    in
      mkIf (cfg.session == "wm" && cfg.preset == "niri") {
        systemd.services."getty@tty1" = {
          overrideStrategy = "asDropin";
          serviceConfig.ExecStart = [
            ""
            "${pkgs.util-linux}/sbin/agetty --login-program ${config.services.getty.loginProgram} --autologin ${machine.user} --noclear %I $TERM"
          ];
        };
        shanetrs.shell.extraRc = ''
          case "$(tty)" in
            /dev/tty1|/dev/tty7) niri-session -l && exit ;;
          esac
        '';
        xdg.portal = xdgPortalConf;
        user = {
          dbus.packages = with pkgs; [niri];
          home = {
            packages = with pkgs; [
              niri
              xwayland-satellite
              adwaita-icon-theme
            ];
            sessionVariables = {
              SCREENSHOT = "niri msg action screenshot";
              LAUNCHER = "${getExe pkgs.rofi} -show drun";
            };
          };
          xdg.portal = xdgPortalConf;
          services.gnome-keyring.enable = true;
        };
      })
  ]);
}
