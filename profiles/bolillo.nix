{
  config,
  pkgs,
  machine,
  ...
}: {
  services.earlyoom.enable = false;
  zramSwap.enable = false;

  shanetrs = {
    enable = true;
    browser.firefox.enable = true;
    desktop = {
      enable = true;
      type = "wayland";
      session = "xfce";
    };
    remote = {
      enable = true;
      audio.enable = false;
      role = "client";
    };
    programs = {
      easyeffects.enable = true;
      zed-editor.enable = true;
    };
    shell.zsh.enable = true;
    tundra.appStores = [];
  };

  networking.firewall = {
    allowedTCPPorts = [8080];
    allowedUDPPorts = [8080];
  };

  environment.sessionVariables = {inherit (config.user.home.sessionVariables) KODI_DATA;};
  services.displayManager.autoLogin.user = machine.user;
  services.xserver = {
    enable = true;
    desktopManager.kodi = {
      package = config.user.programs.kodi.package;
      enable = true;
    };
    # displayManager.lightdm.greeter.enable = false;
  };

  user = let
    datadir = "${config.user.xdg.dataHome}/kodi";
    widevine = "${pkgs.stable.widevine-cdm}/share/google/chrome/WidevineCdm";

    third-party = let
      inherit (pkgs.stable.kodiPackages) buildKodiAddon;
      src = pkgs.fetchFromGitHub {
        owner = "matthuisman";
        repo = "slyguy.addons";
        rev = "e684ee9bdb6a3a8efafb1329222415f39f49329c";
        hash = "sha256-d4V6TxV4aDtARdrpE8QNWJ6GzlJKVPzURWq0O/sfjGg=";
      };
    in rec {
      slyguy = buildKodiAddon {
        pname = "slyguy";
        namespace = "script.module.slyguy";
        version = "0.85.69";
        propagatedBuildInputs = [slyguy_deps slyguy_repo];
        inherit src;
        meta = {
          homepage = "https://github.com/matthuisman/slyguy.addons/tree/master/script.module.slyguy";
          description = "Common code, proxy and settings required by all Slyguy add-ons";
        };
      };
      slyguy_deps = buildKodiAddon {
        pname = "slyguy";
        namespace = "slyguy.dependencies";
        version = "0.0.22";
        propagatedBuildInputs = [slyguy_repo];
        inherit src;
        meta = {
          homepage = "https://github.com/matthuisman/slyguy.addons/tree/master/slyguy.dependencies";
          description = "Dependencies required by all Slyguy add-ons";
        };
      };
      slyguy_repo = buildKodiAddon {
        pname = "slyguy";
        namespace = "repository.slyguy";
        version = "0.0.9";
        propagatedBuildInputs = [];
        inherit src;
        meta = {
          homepage = "https://github.com/matthuisman/slyguy.addons/blob/master/repository.slyguy";
          description = "Addons by SlyGuy (slyguy.uk)";
        };
      };
      disney_plus = buildKodiAddon {
        pname = "disney.plus";
        namespace = "slyguy.disney.plus";
        version = "0.20.2";
        propagatedBuildInputs = [slyguy];
        inherit src;
        meta = {
          homepage = "https://github.com/matthuisman/slyguy.addons/tree/master/slyguy.disney.plus";
          description = "Disney+ is the exclusive home for your favorite movies and TV shows from Disney, Pixar, Marvel, Star Wars, and National Geographic.";
        };
      };
      hulu = buildKodiAddon {
        pname = "hulu";
        namespace = "slyguy.hulu";
        version = "0.4.3";
        propagatedBuildInputs = [slyguy];
        inherit src;
        meta = {
          homepage = "https://github.com/matthuisman/slyguy.addons/tree/master/slyguy.hulu";
          description = "Watch movies, new TV shows, Hulu Originals, and more with Hulu";
        };
      };
      max = buildKodiAddon {
        pname = "max";
        namespace = "slyguy.max";
        version = "0.1.7";
        propagatedBuildInputs = [slyguy];
        inherit src;
        meta = {
          homepage = "https://github.com/matthuisman/slyguy.addons/tree/master/slyguy.max";
          description = "Say hello to Max, the streaming platform that bundles all of HBO together with even more of your favorite movies and TV series, plus new Max Originals.";
        };
      };
    };
  in {
    home = {
      packages = [pkgs.jellyfin-mpv-shim];
      file = {
        "${datadir}/cdm/libwidevinecdm.so".source = "${widevine}/_platform_specific/linux_x64/libwidevinecdm.so";
        "${datadir}/cdm/manifest.json".source = "${widevine}/manifest.json";
      };
    };
    programs.kodi = {
      enable = true;
      inherit datadir;
      package = pkgs.stable.kodi.withPackages (addons: [
        third-party.disney_plus
        third-party.hulu
        addons.jellyfin
        addons.jellycon
        third-party.max
        addons.netflix
        addons.youtube
      ]);
      # settings = { videolibrary.showemptytvshows = "true"; };
      # addonSettings = { "service.xbmc.versioncheck".versioncheck_enable = "false"; };
      # sources = {};
    };
  };
}
