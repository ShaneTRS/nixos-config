{ functions, pkgs, settings, ... }: {
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = [ "quiet" "splash" ];
  };

  zramSwap = {
    enable = true;
    memoryPercent = 70;
  };

  environment.systemPackages = with pkgs; [ local.not-nice ];
  programs.dconf.enable = true; # Enable dconf for GTK apps
  security.rtkit.enable = true; # Interactive privilege escalation

  users.users.${settings.user} = {
    isNormalUser = true;
    hashedPasswordFile = functions.configs "passwd";
    extraGroups = [ "networkmanager" "wheel" "realtime" ];
  };

  shanetrs = {
    browser = {
      enable = true;
      exec = "firefox";
    };
    desktop = {
      enable = true;
      session = "plasma";
    };
    gaming = {
      epic.enable = true;
      minecraft.enable = true;
      steam.enable = true;
    };
    remote = {
      enable = true;
      role = "host";
    };
    programs.vscode.enable = true;
    shell = {
      enable = true;
      exec = "zsh";
    };
  };

  home-manager.users.${settings.user} = {
    home = {
      packages = with pkgs; [
        (discord-canary.override {
          withOpenASAR = true;
          withVencord = true;
        })
        easyeffects
        gimp
        helvum
        jellyfin-media-player
        obs-studio
        # prismlauncher
        (writeShellApplication {
          name = "persephone.audio";
          runtimeInputs = with pkgs; [ noisetorch pulseaudio local.addr-sort ];
          text = ''
            set +o errexit # disable exit on error
            if [ -z "''${THAT:-}" ]; then
              # shellcheck disable=SC2048 disable=SC2086
              THAT=$(addr-sort ''${CLIENT[*]})
            fi

            # pactl unload-module module-null-sink
            pactl load-module module-switch-on-connect # load bluetooth auto-connect pulse module
            pactl load-module module-null-sink sink_name=alvr-output sink_properties=device.description='ALVR Speakers'
            pactl load-module module-null-sink media.class=Audio/Source/Virtual sink_name=alvr-input sink_properties=device.description='ALVR Microphone'

            noisetorch -u
            noisetorch -i -s "$(pactl get-default-source)" -t 1 &
            # shellcheck disable=SC2016
            ssh "$THAT" -f 'systemctl restart --user roc-recv.service'
            # ^ This requires the keys to be stored on this machine
            # ^ And it needs to be rewritten

            pkill shadowplay -USR1
            exec true
          '';
        })
        vlc
      ];
      stateVersion = "23.11";
    };
  };

  system.stateVersion = "23.11";
}
