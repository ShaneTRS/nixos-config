{ pkgs, lib, ... }: {

  environment.systemPackages = with pkgs; [ libsForQt5.xp-pen-deco-01-v2-driver ];
  services.zerotierone.enable = true;

  shanetrs = {
    browser = {
      firefox.enable = true;
      chromium.enable = true;
    };
    desktop = {
      enable = true;
      session = "plasma";
      extraPackages = lib.mkOptionDefault (with pkgs; [ wacomtablet libsForQt5.kolourpaint ]);
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
        features = [ "nix" ];
      };
    };
    shell = {
      default = pkgs.zsh;
      zsh.enable = true;
      doas.enable = true;
    };
  };

  user = {
    programs = { obs-studio.enable = true; };
    home = {
      packages = with pkgs; [
        audacity
        gimp
        helvum
        krita
        jellyfin-media-player
        protontricks
        r2modman
        local.spotify
        vlc
      ];
    };
  };

}
