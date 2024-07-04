{ pkgs, ... }: {

  environment.systemPackages = with pkgs; [ local.not-nice ];
  programs.dconf.enable = true; # Enable dconf for GTK apps

  shanetrs = {
    enable = true;
    browser.firefox.enable = true;
    desktop = {
      enable = true;
      session = "plasma";
    };
    gaming = {
      epic.enable = true;
      minecraft.enable = true;
      steam.enable = true;
      gamescope.enable = true;
    };
    remote = {
      enable = true;
      role = "host";
    };
    programs = {
      discord.enable = true;
      easyeffects.enable = true;
      vscode.enable = true;
    };
    shell.zsh.enable = true;
  };

  user = {
    programs.obs-studio.enable = true;
    home.packages = with pkgs; [
      gimp
      helvum
      jellyfin-media-player
      obs-studio
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
  };
}
