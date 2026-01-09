{pkgs, ...}: {
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
    home.packages = with pkgs; [
      gimp3-with-plugins
      krita
      helvum
      shanetrs.moonlight-qt
      shanetrs.spotify
      vlc
    ];
  };
}
