{ config, functions, lib, pkgs, settings, ... }:
let
  cfg = config.shanetrs.desktop;
  inherit (lib) mkDefault mkEnableOption mkIf mkMerge mkOption types;
in {
  # TODO: Maybe rewrite this to match the new browser.nix implementation?
  # shanetrs.desktop.plasma.enable = true; instead of
  # shanetrs.desktop = { enable = true; exec = "plasma"; };
  options.shanetrs.desktop = let
    sessions = {
      "gnome" = {
        presets = [ "pop" ];
        "pop".extraPackages = with pkgs.gnomeExtensions; [ pop-shell ];
      };
      "plasma" = {
        presets = [ ];
        "default".extraPackages = with pkgs.libsForQt5; [
          ark
          filelight
          kate
          kfind
          pkgs.krename
          plasma-browser-integration
          sddm-kcm
        ];
      };
      "xfce" = {
        presets = [ "win95" ];
        "default".extraPackages = with pkgs.xfce; [ xfce4-panel-profiles ];
        "win95".extraPackages = with pkgs; [ palemoon-bin ];
      };
    };
  in {
    enable = mkEnableOption "Desktop environment and display manager configuration";
    session = mkOption { type = types.enum (builtins.attrNames sessions); };
    type = mkOption {
      type = types.enum [ "x11" "wayland" ];
      default = "x11";
    };
    preset = mkOption {
      type = types.enum (sessions."${cfg.session}".presets ++ [ "default" ]);
      default = "default";
    };
    audio = mkOption {
      type = types.bool;
      default = true;
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default =
        (if (cfg.preset != "default") then sessions."${cfg.session}"."${cfg.preset}".extraPackages or [ ] else [ ])
        ++ (sessions."${cfg.session}"."default".extraPackages or [ ]);
      example = with pkgs; [ flite ];
    };
  };

  config = mkIf cfg.enable (mkMerge [
    { xdg.portal.enable = true; }

    (mkIf cfg.audio {
      sound.enable = true;
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
      services.xserver = {
        enable = true;
        displayManager.autoLogin = {
          enable = mkDefault true;
          user = settings.user;
        };
        xkb.options = "compose:menu";
      };
      user.home.file.".XCompose" = let attempt = builtins.tryEval (functions.configs ".XCompose");
      in mkIf attempt.success { source = attempt.value; };
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
      programs.partition-manager.enable = true;
      user = {
        home.packages = cfg.extraPackages;
        programs = {
          firefox = {
            # Make compatible with browser module, by inheriting its setting and applying our own slightly stronger
            package = lib.mkOverride 95 ((config.shanetrs.browser.firefox.package or pkgs.firefox).override {
              nativeMessagingHosts = [ pkgs.libsForQt5.plasma-browser-integration ];
            });
            policies.ExtensionSettings."plasma-browser-integration@kde.org" = mkDefault {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/plasma-integration/latest.xpi";
              installation_mode = "force_installed"; # Prevents uninstalling without config
            };
          };
          chromium.extensions = [{ id = "cimiefiiaegbelhefglklhhakcgmhkai"; }]; # Plasma Integration
        };
        services.kdeconnect = {
          enable = true;
          indicator = true;
        };
      };
      services.xserver = {
        displayManager = {
          sddm.enable = true;
          sddm.wayland.enable = mkIf (cfg.type == "wayland") true;
          defaultSession = if cfg.type == "x11" then "plasma" else "plasmawayland";
        };
        desktopManager.plasma5.enable = true;
      };
    })

    (mkIf (cfg.session == "xfce") {
      xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
      services.xserver = {
        displayManager.defaultSession = "xfce";
        desktopManager.xfce.enable = true;
      };
      user.home.packages = cfg.extraPackages;
    })

    (mkIf (cfg.session == "xfce" && cfg.preset == "win95") (let chicago95 = pkgs.local.chicago95;
    in {
      fonts = {
        packages = [ chicago95 ];
        fontconfig.allowBitmaps = true;
      };
      environment.systemPackages = with pkgs.xfce; [ xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin ];
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
        systemd.user.services.chicago95 = {
          Unit.Description = "Install Chicago95";
          Service.ExecStart = "${chicago95}/import/install.sh";
          Install.WantedBy = [ "default.target" ];
        };
        xsession = {
          enable = true;
          profileExtra = ''
            pw-play "${chicago95}/share/sounds/Chicago95/startup.ogg" & true
          '';
        };
      };
    }))
  ]);
}
