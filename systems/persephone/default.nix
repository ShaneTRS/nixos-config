{
  config,
  machine,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getExe mkIf mkOptionDefault;
  inherit (lib.tundra) getConfig;
in {
  config.shanetrs = {
    enable = true;
    browser.firefox = {
      enable = true;
      pwa.enable = true;
    };
    desktop = {
      enable = true;
      session = "plasma";
      keymap = let
        xdotool = getExe pkgs.xdotool;
        launch = cmd: {launch = [(getExe (pkgs.writeShellScriptBin "xremap-launch" cmd))];};
      in {
        keymap = [
          {
            name = "global";
            remap = {
              super-p = launch "ssh shanetrs.remote.client systemctl --user restart audio-fix";
              super-shift-s = launch ''
                [[ "$(ls /tmp/clipboard-*.png | wc -l)" -gt 24 ]] && rm /tmp/clipboard-*.png
                file="/tmp/clipboard-$RANDOM.png"
                spectacle -brno "$file"
                sleep 0.1
                [ ! -f "$file" ] && exit 1
                ${getExe pkgs.xclip} -sel c -t image/png -i < "$file"
              '';
              super-space = launch ''
                p=$(${xdotool} getwindowpid $(${xdotool} getactivewindow))
                ps=($(cat /proc/$p/stat)); s=9
                [ ''${ps[2]} == 'T' ] && ((s-=1))
                kill -1$s $p
              '';
            };
          }
        ];
        modmap = [
          {
            name = "menu";
            remap = {
              leftmeta = {
                press = launch ''
                  date +%s%N > /tmp/xremap.menu
                '';
                release = launch ''
                  since=$(( ( $(date +%s%N) - $(cat /tmp/xremap.menu || echo 0) ) / 1000000 ))
                  if [[ $since -lt 150 || $since -gt 12500 ]]; then
                    ${pkgs.kdePackages.qttools}/bin/qdbus org.kde.kglobalaccel /component/kwin \
                      org.kde.kglobalaccel.Component.invokeShortcut Overview
                  fi
                '';
              };
            };
          }
        ];
      };
      extraPackages = with pkgs; mkOptionDefault [kdePackages.wacomtablet kdePackages.kdenlive];
    };
    gaming = {
      epic.enable = true;
      emulation.enable = true;
      lutris.enable = true;
      mangohud.enable = true;
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
      usb.enable = true;
      role = "host";
      audio.source.priority = 1300;
    };
    programs = {
      discord.enable = true;
      easyeffects.enable = true;
      vscode.enable = true;
      zed-editor.enable = true;
      zerotier-one.enable = true;
      gimp.enable = true;
    };
    shell = {
      default = pkgs.zsh;
      bash.enable = true;
      zsh.enable = true;
      doas.noPassCmds = mkOptionDefault ["chrt" "iptables"];
    };
    shell.enable = true;
  };

  nixos = {
    environment.systemPackages = with pkgs; [shanetrs.not-nice iptables];
    programs = {
      dconf.enable = true; # Enable dconf for GTK apps
      noisetorch.enable = true;
    };
    users = {
      groups = {
        uinput.gid = 990;
        adbusers.members = [machine.user];
        vboxusers.members = [machine.user];
      };
      users.${machine.user} = {
        subGidRanges = [
          {
            count = 1;
            startGid = config.users.groups.input.gid;
          }
          {
            count = 1;
            startGid = config.users.groups.uinput.gid;
          }
        ];
      };
    };

    services = {
      ddclient.enable = true;
      udev = {
        enable = true;
        packages = [pkgs.shanetrs.vuinputd];
        extraHwdb = ''
          evdev:input:b0003v1209p5020e????-*
           ID_VUINPUT=1

          input:b0003v1209p5020e????-*
           ID_VUINPUT=1
        '';
      };
    };

    systemd.user.services = {
      keynav.enable = true;
      jfa-go.enable = true;
    };

    boot.kernelParams = ["kvm.enable_virt_at_load=0"];
    virtualisation = {
      virtualbox.host = {
        enable = true;
        enableExtensionPack = true;
        enableHardening = false;
      };
      podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
        extraPackages = [pkgs.slirp4netns];
      };
    };
  };

  home = {
    programs.obs-studio.enable = true;
    home.packages = with pkgs; [
      audacity # audio editor
      krita # drawing
      inkscape-with-extensions # vector editor
      libreoffice-still # office suite
      equibop # discord client

      crosspipe # patchbay
      spicetify-cli # spotify mods
      shanetrs.spotify # music player

      scrcpy # android-to-pc casting
      vlc # media player

      jetbrains.idea-oss # java dev
      podman-desktop # container management
      podman-compose # declarative containers
      distrobox # incompetence

      shanetrs.shadowplay

      qbittorrent # download client
      tor-browser # private web browser

      shanetrs.alchemy-viewer # metaverse client
      shanetrs.jfa-go # jellyfin temp. accounts
      shanetrs.schud # controller overlay
    ];
    xdg.configFile."keynav/keynavrc" = let
      attempt = getConfig "keynavrc";
    in
      mkIf (attempt != null) {source = attempt;};
  };

  machine.user = "shane";
}
