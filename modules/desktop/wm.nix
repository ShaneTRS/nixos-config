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
        brightnessctl = getExe pkgs.brightnessctl;
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

              brightnessup = launch "${brightnessctl} --class=backlight set 1%+";
              brightnessdown = launch "${brightnessctl} --class=backlight set 1%-";
            };
          }
          {
            name = "programs";
            remap = {
              super-t = launch "\"\${TERMINAL[@]}\" || true";
              super-e = launch "\"\${FILE_MANAGER[@]}\" || true";
              super-shift-s = launch "\"\${SCREENSHOT[@]}\" || true";
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
        systemd.services."getty@tty1".serviceConfig.ExecStart = [
          ""
          "/sbin/agetty --noreset --noclear --autologin ${machine.user} --keep-baud tty1 38400 linux"
        ];
        shanetrs.shell.extraRc = ''
          case "$(tty)" in
            /dev/tty1|/dev/tty7) exec niri-session -l ;;
          esac
        '';
        xdg.portal = xdgPortalConf;
        user = {
          dbus.packages = with pkgs; [niri];
          home = {
            packages = with pkgs; [
              niri
              xwayland-satellite
            ];
            sessionVariables = {SCREENSHOT = "niri msg action screenshot";};
          };
          xdg.portal = xdgPortalConf;
          services.gnome-keyring.enable = true;
        };
      })
  ]);
}
