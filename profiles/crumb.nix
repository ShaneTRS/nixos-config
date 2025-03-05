{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOptionDefault;
in {
  services.zerotierone.enable = true;

  shanetrs = {
    enable = true;
    browser = {
      firefox.enable = true;
      chromium.enable = true;
    };
    desktop = {
      enable = true;
      session = "plasma";
      extraPackages = with pkgs; mkOptionDefault [wacomtablet kdePackages.kolourpaint];
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
      vscode = {
        enable = true;
        features = ["nix"];
      };
    };
    shell.zsh.enable = true;
  };

  user = {
    programs.obs-studio.enable = true;
    home = {
      packages = with pkgs; [
        audacity
        gimp
        helvum
        krita
        jellyfin-media-player
        protontricks
        r2modman
        shanetrs.spotify
        vlc
      ];
    };
  };
}
