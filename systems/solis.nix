{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOptionDefault;
in {
  nixos.services.printing.enable = true;
  config.shanetrs = {
    enable = true;
    browser.chromium.enable = true;
    desktop = {
      enable = true;
      session = "plasma";
      extraPackages = with pkgs; mkOptionDefault [kdePackages.kcalc];
    };
    programs = {
      vscode.enable = true;
      gimp.enable = true;
    };
  };

  home.home.packages = with pkgs; [flatpak libreoffice-still vlc];
}
