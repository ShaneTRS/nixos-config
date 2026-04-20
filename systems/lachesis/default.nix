{pkgs, ...}: {
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
    serviceConfig.Type = "oneshot";
    script = ''
      set +o errexit
      sleep 5
      until ${pkgs.inetutils}/bin/ping -qs1 -c1 -W1 shanetrs.remote.host; do
        sleep 1
      done
      ${pkgs.systemd}/bin/systemctl restart --user pipewire-pulse pipewire
      ${pkgs.noisetorch}/bin/noisetorch -i -t 30
      true
    '';
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
