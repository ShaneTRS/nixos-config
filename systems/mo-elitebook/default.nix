{pkgs, ...}: {
  services.earlyoom.enable = false;
  zramSwap.enable = false;
  programs.noisetorch.enable = true;

  shanetrs = {
    enable = true;
    browser.firefox.enable = true;
    desktop = {
      enable = true;
      plasma.enable = true;
    };
    programs = {
      discord.enable = true;
      easyeffects.enable = true;
      zed-editor.enable = true;
      gimp.enable = true;
    };
    shell.zsh.enable = true;
  };

  tundra = {
    user = "mo";
    packages = with pkgs; [
      krita
      crosspipe
      shanetrs.moonlight-qt
      shanetrs.spotify
      vlc
    ];
  };
}
