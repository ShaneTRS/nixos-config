{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOptionDefault;
in {
  services.printing.enable = true;
  shanetrs = {
    enable = true;
    browser.chromium.enable = true;
    desktop = {
      enable = true;
      plasma = {
        enable = true;
        extraPackages = with pkgs; mkOptionDefault [kdePackages.kcalc];
      };
    };
    programs.gimp.enable = true;
  };
  tundra.packages = with pkgs; [flatpak libreoffice-still vlc];
}
