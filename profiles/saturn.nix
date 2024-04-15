{ functions, pkgs, machine, ... }: {
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = [ "quiet" "splash" ];
  };

  zramSwap = {
    enable = true;
    memoryPercent = 70;
  };

  environment.systemPackages = with pkgs; [ git vlc ];

  services.flatpak.enable = true;
  security.rtkit.enable = true; # Interactive privilege escalation
  system.autoUpgrade.enable = true;

  users.users.${machine.user} = {
    isNormalUser = true;
    hashedPasswordFile = functions.configs "passwd";
    extraGroups = [ "networkmanager" "wheel" "realtime" ];
  };

  shanetrs = {
    browser = {
      enable = true;
      exec = "chromium";
    };
    desktop = {
      enable = true;
      session = "plasma";
    };
    gaming = {
      # epic.enable = true;
      minecraft.enable = true;
      steam.enable = true;
    };
    remote = {
      enable = true;
      package = pkgs.tigervnc;
      role = "host";
    };
    programs.vscode.enable = true;
    shell = {
      enable = true;
      exec = "zsh";
    };
  };

  user = {
    home = {
      packages = with pkgs; [
        (discord-canary.override {
          withOpenASAR = true;
          withVencord = true;
        })
        flatpak
        gnome.gnome-software
        krita
      ];
      stateVersion = "23.11";
    };
  };

  system.stateVersion = "23.11";
}
