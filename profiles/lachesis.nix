{ pkgs, ... }: {

  # These aren't needed on a thin-client
  services.earlyoom.enable = false;
  zramSwap.enable = false;

  shanetrs = {
    browser.firefox.enable = true;
    desktop = {
      enable = true;
      session = "plasma";
    };
    remote = {
      enable = true;
      role = "client";
      usb.ports = [ "2-2" "2-4" ];
    };
    programs = {
      discord.enable = true;
      easyeffects.enable = true;
      vscode = {
        enable = true;
        features = [ "nix" ];
      };
    };
    shell = {
      default = pkgs.zsh;
      zsh.enable = true;
      doas.enable = true;
    };
  };

  user = {
    programs.obs-studio.enable = true;
    home.packages = with pkgs; [
      helvum
      jellyfin-media-player
      moonlight-qt
      local.spotify
      vlc
      (writeShellScriptBin "backlight-8b501" ''
        #!/bin/sh
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
  };
}
