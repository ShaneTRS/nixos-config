{ config, functions, lib, pkgs, machine, ... }:
let
  cfg = config.shanetrs.desktop;
  inherit (builtins) attrNames;
  inherit (functions) configs;
  inherit (lib) mkDefault mkEnableOption mkIf mkMerge mkOption mkOptionDefault types;
  this = sessions.${cfg.session}.${cfg.preset} or { };
  presets = attrNames sessions.${cfg.session};
  sessions = {
    plasma = rec {
      default = {
        desktop = "plasma6";
        extraPackages = with pkgs.${this.libs}; [
          ark
          filelight
          kate
          kfind
          pkgs.krename
          plasma-browser-integration
          sddm-kcm
        ];
        libs = "kdePackages";
      };
      plasma5 = default // {
        desktop = "plasma5";
        libs = "libsForQt5";
      };
      plasma6 = default;
    };
    gnome.pop.extraPackages = with pkgs.gnomeExtensions; [ pop-shell ];
    xfce = rec {
      default.extraPackages = with pkgs.xfce; [ xfce4-panel-profiles ];
      win95 = { extraPackages = with pkgs; [ palemoon-bin ]; } // default;
    };
  };
in {
  options.shanetrs.desktop = {
    enable = mkEnableOption "Desktop environment and display manager configuration";
    session = mkOption {
      type = types.nullOr (types.enum (attrNames sessions));
      default = null;
    };
    type = mkOption {
      type = types.enum [ "x11" "wayland" ];
      default = "x11";
    };
    preset = mkOption {
      type = types.enum (presets ++ [ "default" ]);
      default = "default";
    };
    audio = mkOption {
      type = types.bool;
      default = true;
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = this.extraPackages or [ ];
      example = with pkgs; [ flite ];
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      hardware.bluetooth.enable = true;
      security.rtkit.enable = true; # Interactive privilege escalation
      xdg.portal.enable = true;
      user.home.packages = cfg.extraPackages;
    }

    (mkIf cfg.audio {
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
      };
    })

    # Or Plasma, because SDDM requires the X Server
    (mkIf (cfg.type == "x11" || cfg.session == "plasma") {
      services = {
        displayManager.autoLogin = {
          enable = mkDefault true;
          user = machine.user;
        };
        xserver = {
          enable = true;
          xkb.options = "compose:menu";
        };
      };
      user = {
        xsession = {
          enable = true;
          profileExtra = ''
            XCOMPOSEFILE="$HOME/.config/XCompose"
            XCOMPOSECACHE="$HOME/.cache/XCompose"
          '';
        };
        xdg.configFile."XCompose" = let attempt = configs ".XCompose"; in mkIf (attempt != null) { source = attempt; };
      };
    })

    (mkIf (cfg.session == "gnome") {
      xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-gnome ];
      # environment.gnome.excludePackages
      user = {
        dconf = {
          enable = true;
          settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
        };
      };
      services.xserver = {
        displayManager.gdm.enable = true;
        desktopManager.gnome.enable = true;
      };
      # Workaround for a bug
      systemd.services = {
        "getty@tty1".enable = false;
        "autovt@tty1".enable = false;
      };
    })

    (mkIf (cfg.session == "gnome" && cfg.preset == "pop") {
      user = {
        dconf.settings = { "org/gnome/shell".enabled-extensions = [ "pop-shell@system76.com" ]; };
        home.packages = with pkgs; [ gnomeExtensions.pop-shell ];
      };
    })

    (mkIf (cfg.session == "plasma") {
      xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-kde ];
      # Maybe try to use plasma-manager for some settings
      programs = {
        kdeconnect.enable = true;
        partition-manager.enable = true;
      };
      shanetrs.browser = {
        firefox = {
          extensions = mkOptionDefault [ "plasma-browser-integration@kde.org:plasma-integration/latest" ];
          _.nativeMessagingHosts = mkOptionDefault [ pkgs.${this.libs}.plasma-browser-integration ];
        };
        chromium.extensions = mkOptionDefault [ "cimiefiiaegbelhefglklhhakcgmhkai" ]; # Plasma Integration
      };
      user.services.kdeconnect = {
        enable = true;
        indicator = true;
      };
      services = {
        displayManager = {
          sddm = {
            enable = true;
            wayland.enable = mkIf (cfg.type == "wayland") true;
          };
          defaultSession = if cfg.type == "x11" then "plasmax11" else "plasma";
        };
        desktopManager.${this.desktop or null}.enable = true;
      };
    })

    (mkIf (cfg.session == "xfce") {
      xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
      services = {
        displayManager.defaultSession = "xfce";
        xserver.desktopManager.xfce.enable = true;
      };
    })

    (let chicago95 = pkgs.local.chicago95;
    in mkIf (cfg.session == "xfce" && cfg.preset == "win95") {
      fonts = {
        packages = [ chicago95 ];
        fontconfig.allowBitmaps = true;
      };
      environment.systemPackages = with pkgs.xfce; [ xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin ];
      systemd.user.services.chicago95 = {
        serviceConfig.ExecStart = "${chicago95}/import/install.sh";
        wantedBy = [ "default.target" ];
      };
      user = {
        xdg.configFile = {
          "gtk-3.0" = {
            recursive = true;
            source = "${chicago95}/import/gtk-3.0/";
          };
          "xfce4" = {
            recursive = true;
            source = "${chicago95}/import/xfce4/";
          };
        };
        home = {
          file = {
            ".gtkrc-2.0".source = "${chicago95}/import/.gtkrc-2.0";
            ".moonchild productions" = {
              recursive = true;
              source = "${chicago95}/import/.moonchild productions/";
            };
          };
          packages = [ chicago95 ];
        };
        xsession = {
          enable = true;
          profileExtra = ''
            pw-play "${chicago95}/share/sounds/Chicago95/startup.ogg" & true
          '';
        };
      };
    })
  ]);
}
