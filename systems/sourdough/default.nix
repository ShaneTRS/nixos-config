{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOptionDefault;
in {
  services.flatpak.enable = true;
  shanetrs = {
    enable = true;
    browser = {
      firefox.enable = true;
      chromium.enable = true;
    };
    desktop = {
      enable = true;
      plasma = {
        enable = true;
        extraPackages = with pkgs; mkOptionDefault [kdePackages.wacomtablet kdePackages.kolourpaint];
      };
    };
    gaming = {
      epic.enable = true;
      emulation.enable = true;
      lutris.enable = true;
      mangohud.enable = true;
      minecraft.enable = true;
      steam.enable = true;
      gamescope.enable = true;
    };
    programs = {
      discord.enable = true;
      easyeffects.enable = true;
      zed-editor.enable = true;
      zerotier-one.enable = true;
      gimp.enable = true;
    };
    shell.zsh.enable = true;
  };
  programs = {
    dconf.enable = true;
    noisetorch.enable = true;
  };
  tundra.packages = with pkgs; [
    aseprite # pixel editor
    audacity # audio editor
    blender # 3d modeling
    krita # drawing
    inkscape-with-extensions # vector editor
    moonlight-qt # game streamer

    crosspipe # patchbay
    libreoffice-still # office suite
    r2modman # mod manager
    shanetrs.spotify # music player
    vlc # media player

    distrobox # incompetence
  ];
}
