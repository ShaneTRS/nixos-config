{
  pkgs,
  lib,
  ...
}: {
  services.earlyoom.enable = false;
  zramSwap.enable = false;
  programs.noisetorch.enable = true;

  shanetrs = {
    enable = true;
    browser.firefox.enable = true;
    desktop = {
      enable = true;
      session = "plasma";
    };
    remote = {
      enable = true;
      usb.enable = true;
      role = "client";
    };
    programs = {
      discord.enable = true;
      easyeffects.enable = true;
      zed-editor.enable = true;
      vscode = {
        enable = true;
        features = ["nix"];
      };
    };
    shell.zsh.enable = true;
  };

  user = {
    programs.obs-studio.enable = true;
    home.packages = with pkgs; [
      gimp-with-plugins
      helvum
      jellyfin-media-player
      shanetrs.moonlight-qt
      shanetrs.spotify
      vlc
      shanetrs.ml-launcher
      (writeShellScriptBin "backlight-8b501" ''
        export DISPLAY=:0
        mkdir -p /tmp/backlight
        processes=(`pgrep backlight-8b501`)

        max=`cat /sys/class/backlight/intel_backlight/max_brightness`
        bl_set() {
          val=$1
          echo $val
          [[ $val -gt $max ]] && val=$max
          [[ $val -lt 1 ]] && val=1
          echo "$val" > /tmp/backlight/actual_brightness
          dbus-send --session --type=method_call --dest=org.kde.Solid.PowerManagement \
            "/org/kde/Solid/PowerManagement/Actions/BrightnessControl" org.kde.Solid.PowerManagement.Actions.BrightnessControl.setBrightness int32:$val &
          true
        }
        bl_set_perc () { bl_set $((max * $1 / 100)); }
        bl_step () { bl_set $(( `cat /tmp/backlight/actual_brightness || cat /sys/class/backlight/intel_backlight/actual_brightness` + $1)); }
        bl_step_perc () { bl_step $((max * $1 / 100)); }

        [[ "$2" ]] || exit
        val=''${val:-$(( $2*''${#processes[@]} ))}
        eval "bl_$1 $val"
        sleep 0.2
      '')
    ];
    systemd.user.services = {
      audio-fix = {
        Unit = {
          After = "pipewire.service";
          Description = "Bandage fix for not forwarding audio at boot";
        };
        Service = {
          Environment = ["TARGET=shanetrs.remote.host" "MIN_DELAY=5"];
          ExecStart = let
            inherit (pkgs) writeShellApplication;
            inherit (lib) getExe;
          in "${getExe (writeShellApplication {
            name = "audio-fix.service";
            runtimeInputs = with pkgs; [inetutils];
            text = ''
              set +o errexit
              sleep "$MIN_DELAY"
              until ping -qs1 -c1 -W1 "$TARGET"; do
                sleep 1
              done
              systemctl restart --user pipewire-pulse pipewire
              noisetorch -i
            '';
          })}";
          Restart = "on-failure";
          StartLimitBurst = 32;
        };
        Install.WantedBy = ["graphical-session.target"];
      };
    };
  };
}
