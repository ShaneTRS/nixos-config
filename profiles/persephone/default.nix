{
  fn,
  machine,
  pkgs,
  lib,
  ...
}: let
  inherit (fn) configs;
  inherit (lib) mkIf mkOptionDefault;
in {
  imports = [./services.nix];

  environment.systemPackages = with pkgs; [shanetrs.not-nice];
  programs = {
    dconf.enable = true; # Enable dconf for GTK apps
    noisetorch.enable = true;
    adb.enable = true; # Adds udev rules, adb, and creates group
  };
  users.users.${machine.user}.extraGroups = ["adbusers"];

  services = {
    ddclient.enable = true;
    zerotierone.enable = true;
  };
  systemd.user.services = {
    keynav.enable = true;
    jfa-go.enable = true;
  };

  shanetrs = {
    enable = true;
    browser.firefox = {
      enable = true;
      pwa.enable = true;
    };
    desktop = {
      enable = true;
      session = "plasma";
      keymap.keymap = [
        {
          name = "global";
          remap = {
            # quick access
            "alt-shift-q" = {
              timeout_key = "leftmeta";
              timeout_millis = 750;
              exact_match = true;
              remap = {
                # discord
                d = {
                  launch = [
                    "/home/shane/Documents/Scripts/window"
                    "windowactivate"
                    "--name"
                    "Equibop"
                    "--"
                    "equibop"
                  ];
                };
                # editor
                e = {
                  launch = [
                    "/home/shane/Documents/Scripts/window"
                    "windowactivate"
                    "--class"
                    "Zed"
                    "--"
                    "zeditor"
                  ];
                };
                # firefox
                f = {
                  launch = [
                    "/home/shane/Documents/Scripts/window"
                    "windowactivate"
                    "--name"
                    "Firefox"
                    "--"
                    "firefox-developer-edition"
                  ];
                };
                # spotify
                s = {
                  launch = [
                    "/home/shane/Documents/Scripts/window"
                    "windowactivate"
                    "--class"
                    "Spotify"
                    "--"
                    "env LD_PRELOAD=/usr/lib/spotify-adblock.so spotify --uri=%U"
                  ];
                };
                # terminal
                t = {
                  launch = [
                    "/home/shane/Documents/Scripts/window"
                    "windowactivate"
                    "--desktop"
                    "0"
                    "--class"
                    "Konsole"
                    "--"
                    "konsole"
                  ];
                };
              };
            };
            "super-p" = {launch = ["/home/shane/Documents/Scripts/pipewire"];};
            "super-shift-s" = {launch = ["/home/shane/Documents/Scripts/screenshot"];};
            "super-space" = {launch = ["/home/shane/Documents/Scripts/freeze"];};
          };
        }
      ];
      extraPackages = with pkgs; mkOptionDefault [wacomtablet kdePackages.kdenlive];
    };
    gaming = {
      epic.enable = true;
      emulation.enable = true;
      lutris.enable = true;
      minecraft = {
        enable = true;
        extraPackages = with pkgs; [flite];
      };
      steam.enable = true;
      gamescope.enable = true;
      vr = {
        enable = true;
        headsets = ["quest2"];
      };
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
    shell = {
      zsh.enable = true;
      doas.noPassCmds = mkOptionDefault ["chrt"];
    };
  };

  user = {
    programs.obs-studio.enable = true;
    home.packages = with pkgs; [
      audacity # audio editor
      gimp3 # image editor
      krita # drawing
      inkscape-with-extensions # vector editor
      libreoffice-still # office suite

      helvum # patchbay
      spicetify-cli # spotify mods

      jellyfin-media-player # dvd library
      jellyfin-mpv-shim # library casting
      scrcpy # android-to-pc casting
      vlc # media player

      jetbrains.idea-community-bin # java dev
      podman-compose # declarative containers

      shanetrs.shadowplay
      (writeShellApplication {
        name = "persephone.audio";
        runtimeInputs = [noisetorch pulseaudio];
        text = ''
          set +o errexit

          pactl unload-module module-null-sink
          pactl load-module module-switch-on-connect # load bluetooth auto-connect pulse module
          pactl load-module module-null-sink sink_name=alvr-output sink_properties=device.description='ALVR Speakers'
          pactl load-module module-null-sink media.class=Audio/Source/Virtual sink_name=alvr-input sink_properties=device.description='ALVR Microphone'

          pkill shadowplay -USR1
          exec true
        '';
      })

      qbittorrent-qt5 # download client
      tor-browser # private web browser

      shanetrs.wlx-overlay-s # vr desktops
      shanetrs.jfa-go # jellyfin temp. accounts
    ];
    xdg.configFile."keynav/keynavrc" = let
      attempt = configs "keynavrc";
    in
      mkIf (attempt != null) {source = attempt;};
  };

  virtualisation = {
    containers.cdi.dynamic.nvidia.enable = true;
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };
}
