{ pkgs, lib, ... }:
let inherit (lib) mkOptionDefault;
in {
  services.printing.enable = true;
  shanetrs = {
    enable = true;
    browser.chromium.enable = true;
    desktop = {
      enable = true;
      session = "plasma";
      extraPackages = with pkgs; mkOptionDefault [ libsForQt5.kcalc ];
    };
    programs.vscode.enable = true;
  };

  user.home.packages = with pkgs; [ flatpak gimp libreoffice-still vlc ];
}
