{pkgs, ...}: {
  nixos = {
    services.earlyoom.enable = false;
    zramSwap.enable = false;
    programs.noisetorch.enable = true;
  };

  config.shanetrs = {
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
      gimp.enable = true;
    };
    shell.zsh.enable = true;
  };

  home = {
    home.packages = with pkgs; [
      krita
      helvum
      shanetrs.moonlight-qt
      shanetrs.spotify
      vlc
    ];
  };
}
