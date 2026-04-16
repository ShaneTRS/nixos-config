{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOptionDefault;
in {
  services = {
    flatpak.enable = true;
    printing.enable = true;
  };
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
  tundra.packages = with pkgs; [libreoffice-still vlc];
}
