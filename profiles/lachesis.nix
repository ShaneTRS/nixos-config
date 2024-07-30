{ config, pkgs, lib, ... }:
let inherit (lib) concatStringsSep;
in {
  services.earlyoom.enable = false;
  zramSwap.enable = false;

  shanetrs = {
    enable = true;
    browser.firefox.enable = true;
    desktop = {
      enable = true;
      session = "plasma";
    };
    remote = {
      enable = true;
      role = "client";
    };
    programs = {
      discord.enable = true;
      easyeffects.enable = true;
      vscode = {
        enable = true;
        features = [ "nix" ];
      };
    };
    shell.zsh.enable = true;
    tundra.appStores = [ ];
  };

  user = {
    programs.obs-studio.enable = true;
    home.packages = with pkgs; [
      helvum
      jellyfin-media-player
      local.moonlight-qt
      local.spotify
      vlc
      (writeShellApplication {
        name = "moonlight-8b501";
        runtimeInputs = [ coreutils local.addr-sort xorg.xdpyinfo ];
        text = ''
          RESOLUTION="''${RESOLUTION:-$(xdpyinfo | awk '/dimensions/{print $2}')}"
          TARGET="''${TARGET:-$(addr-sort ${concatStringsSep " " config.shanetrs.remote.addresses.host})}"
          PORT="''${PORT:-46989}"
          BITRATE="''${BITRATE:-19000}"
          FPS="''${FPS:-62}"
          echo "Connecting to $TARGET at $RESOLUTION!"
          moonlight stream "$TARGET:$PORT" desktop --resolution "$RESOLUTION" --no-vsync --fps "$FPS" \
          	--bitrate "$BITRATE" --multi-controller --quit-after --game-optimization --audio-on-host \
          	--no-frame-pacing --background-gamepad --capture-system-keys fullscreen \
          	--video-codec H.264 --video-decoder hardware
        '';
      })
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
  };
}
