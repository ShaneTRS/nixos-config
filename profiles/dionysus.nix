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
      session = "xfce";
    };
    remote = {
      enable = true;
      role = "client";
    };
    programs.vscode = {
      enable = true;
      features = [ "nix" ];
    };
    shell.zsh.enable = true;
    tundra.appStores = [ ];
  };

  user.home.packages = with pkgs; [
    local.moonlight-qt
    (writeShellApplication {
      name = "moonlight-8b501";
      runtimeInputs = [ coreutils local.addr-sort xorg.xdpyinfo ];
      text = ''
        ml_res () { xdpyinfo | awk '/dimensions/{print $2}'; }
        ml_target () { addr-sort ${concatStringsSep " " config.shanetrs.remote.addresses.host}; }
        ml_bitrate () {
          [ "$1" == "10.42.0.1" ] && exec echo 65000
          echo 19000
        }
        ml_args () {
          cat <<EOF
            "$APPLICATION" --resolution "$RESOLUTION" --fps "$FPS" --bitrate "$BITRATE" \
            --audio-on-host --quit-after --game-optimization --multi-controller \
            --background-gamepad --capture-system-keys fullscreen \
            --video-codec H.264 --video-decoder hardware --no-vsync --frame-pacing
        EOF
        }

        RESOLUTION="''${RESOLUTION:-$(ml_res)}"
        TARGET="''${TARGET:-$(ml_target)}"
        PORT="''${PORT:-46989}"
        BITRATE="''${BITRATE:-$(ml_bitrate "$TARGET")}"
        FPS="''${FPS:-62}"
        APPLICATION="''${APPLICATION:-desktop}"

        ARGS="''${ARGS:-$(ml_args)}"
        COMMAND="moonlight stream "$TARGET:$PORT" ''${ARGS[*]} $*"

        echo "Connecting to $TARGET at $RESOLUTION!"
        if [ "''${DEBUG:-}" ]; then
          echo "$COMMAND"
          read -rt2
        fi
        eval "$COMMAND"
      '';
    })
  ];
}
