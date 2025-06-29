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
      gimp3-with-plugins
      helvum
      jellyfin-media-player
      shanetrs.moonlight-qt
      shanetrs.spotify
      vlc
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
