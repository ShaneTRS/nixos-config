{
  config,
  fn,
  machine,
  pkgs,
  lib,
  ...
}: let
  inherit (fn) configs;
  inherit (lib) getExe mkIf mkOptionDefault;
in {
  imports = [./services.nix];

  environment.systemPackages = with pkgs; [shanetrs.not-nice iptables];
  programs = {
    dconf.enable = true; # Enable dconf for GTK apps
    noisetorch.enable = true;
    adb.enable = true; # Adds udev rules, adb, and creates group
  };
  users.users.${machine.user}.extraGroups = ["adbusers" "vboxusers"];

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
      keymap = let
        xdotool = getExe pkgs.xdotool;
        launch = cmd: {launch = [(getExe (pkgs.writeShellScriptBin "xremap-launch" cmd))];};
      in {
        keymap = [
          {
            name = "global";
            remap = {
              "super-p" = launch "ssh shanetrs.remote.client systemctl --user restart audio-fix";
              "super-shift-s" = launch ''
                [[ "$(ls /tmp/clipboard-*.png | wc -l)" -gt 24 ]] && rm /tmp/clipboard-*.png
                file="/tmp/clipboard-$RANDOM.png"
                spectacle -brno "$file"
                sleep 0.1
                [ ! -f "$file" ] && exit 1
                ${getExe pkgs.xclip} -sel c -t image/png -i < "$file"
              '';
              "super-space" = launch ''
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
              "leftmeta" = {
                "press" = launch ''
                  exec -a xremap.menu coreutils --coreutils-prog=sleep 0.15
                '';
                "release" = launch ''
                  pgrep -f xremap.menu &&
                    ${pkgs.kdePackages.qttools}/bin/qdbus org.kde.kglobalaccel /component/kwin \
                    org.kde.kglobalaccel.Component.invokeShortcut Overview
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
    };
    shell = {
      zsh.enable = true;
      doas.noPassCmds = mkOptionDefault ["chrt" "iptables"];
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
      shanetrs.spotify # music player
      shanetrs.zotify # music downloader

      scrcpy # android-to-pc casting
      vlc # media player

      jetbrains.idea-community-bin # java dev
      podman-desktop # container management
      podman-compose # declarative containers
      distrobox # incompetence

      shanetrs.shadowplay

      qbittorrent # download client
      tor-browser # private web browser

      shanetrs.alchemy-viewer # metaverse client
      shanetrs.jfa-go # jellyfin temp. accounts
      shanetrs.wlx-overlay-s # vr desktops
    ];
    xdg.configFile."keynav/keynavrc" = let
      attempt = configs "keynavrc";
    in
      mkIf (attempt != null) {source = attempt;};
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
}
