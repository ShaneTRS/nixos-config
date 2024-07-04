{ pkgs, ... }: {

  services.printing.enable = true;
  shanetrs = {
    enable = true;
    browser.chromium.enable = true;
    desktop = {
      enable = true;
      session = "plasma";
      extraPackages = with pkgs; lib.mkOptionDefault [ libsForQt5.kcalc ];
    };
    programs.vscode.enable = true;
  };

  user.home.packages = with pkgs; [ flatpak gimp libreoffice-still vlc ];
}
