{ functions, pkgs, settings, lib, ... }: {
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = [ "quiet" "splash" ];
  };

  environment.systemPackages = with pkgs; [ libsForQt5.xp-pen-deco-01-v2-driver ];
  networking.firewall.enable = false; # Block incoming connections
  security.rtkit.enable = true; # Interactive privilege escalation
  services.zerotierone.enable = true;

  users.users.${settings.user} = {
    isNormalUser = true;
    hashedPasswordFile = functions.configs "passwd";
    extraGroups = [ "networkmanager" "wheel" "realtime" ];
  };

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
    xdg.configFile = {
      "Vencord" = {
        recursive = true;
        source = functions.configs "Vencord";
      };
    };
    programs = { obs-studio.enable = true; };
    home = {
      packages = with pkgs; [
        audacity
        (discord-canary.override {
          withOpenASAR = true;
          withVencord = true;
        })
        gimp
        helvum
        krita
        jellyfin-media-player
        protontricks
        r2modman
        local.spotify
        vlc
      ];
      stateVersion = "23.11";
    };
  };

  system.stateVersion = "23.11";
}
