{
  pkgs,
  lib,
  ...
}: {
  services.earlyoom.enable = false;
  zramSwap.enable = false;
  programs = {
    noisetorch.enable = true;
    obs-studio.enable = true;
  };

  shanetrs = {
    enable = true;
    browser.firefox.enable = true;
    desktop = {
      enable = true;
      plasma.enable = true;
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
      zerotier-one.enable = true;
      gimp.enable = true;
    };
    shell.zsh.enable = true;
  };

  systemd.user.services.audio-fix = {
    after = ["pipewire.service"];
    serviceConfig.Restart = "on-failure";
    environment = {
      TARGET = "shanetrs.remote.host";
      MIN_DELAY = "5";
    };
    script = let
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
    startLimitBurst = 32;
    wantedBy = ["graphical-session.target"];
  };

  tundra = {
    user = "shane";
    packages = with pkgs; [
      crosspipe
      shanetrs.moonlight-qt
      shanetrs.spotify
      vlc
    ];
  };
}
