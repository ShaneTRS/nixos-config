{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOptionDefault;
in {
  nixos.services.zerotierone.enable = true;

  config.shanetrs = {
    enable = true;
    browser = {
      firefox.enable = true;
      chromium.enable = true;
    };
    desktop = {
      enable = true;
      session = "plasma";
      extraPackages = with pkgs; mkOptionDefault [kdePackages.wacomtablet kdePackages.kolourpaint];
    };
    gaming = {
      epic.enable = true;
      minecraft.enable = true;
      steam.enable = true;
      gamescope.enable = true;
    };
    programs = {
      discord.enable = true;
      easyeffects.enable = true;
      zed-editor.enable = true;
      gimp.enable = true;
    };
    shell.zsh.enable = true;
  };

  home = {
    programs.obs-studio.enable = true;
    home = {
      packages = with pkgs; [
        audacity
        crosspipe
        krita
        protontricks
        r2modman
        shanetrs.spotify
        vlc
      ];
    };
  };
}
