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
      # session = "xfce";
    };
    remote = {
      enable = true;
      role = "client";
    };
    programs = {
      easyeffects.enable = true;
      zed-editor.enable = true;
    };
    shell.zsh.enable = true;
    tundra.appStores = [];
  };

  services.cage = {
    inherit (machine) user;
    enable = true;
    program = "${pkgs.kodi-wayland}/bin/kodi-standalone";
  };

  user = let
    datadir = "${config.user.xdg.dataHome}/kodi";
    widevine = "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm";

    slyguy = with pkgs.kodiPackages; let
      src = pkgs.fetchFromGitHub {
        owner = "matthuisman";
        repo = "slyguy.addons";
        rev = "e684ee9bdb6a3a8efafb1329222415f39f49329c";
        hash = "sha256-d4V6TxV4aDtARdrpE8QNWJ6GzlJKVPzURWq0O/sfjGg=";
      };
    in
      map buildKodiAddon [
        {
          pname = "disney.plus";
          namespace = "slyguy.disney.plus";
          version = "0.20.2";

          inherit src;

          propagatedBuildInputs = [
            signals
            inputstream-adaptive
            inputstreamhelper
            requests
            myconnpy
          ];

          meta = {
            homepage = "https://github.com/matthuisman/slyguy.addons/tree/master/slyguy.disney.plus";
            description = "Disney+ is the exclusive home for your favorite movies and TV shows from Disney, Pixar, Marvel, Star Wars, and National Geographic.";
            # license = licenses.mit;
            # maintainers = teams.kodi.members ++ [ maintainers.pks ];
          };
        }
        {
          pname = "hulu";
          namespace = "slyguy.hulu";
          version = "0.4.3";

          inherit src;

          propagatedBuildInputs = with kodiPackages; [
            signals
            inputstream-adaptive
            inputstreamhelper
            requests
            myconnpy
          ];

          meta = {
            homepage = "https://github.com/matthuisman/slyguy.addons/tree/master/slyguy.hulu";
            description = "Watch movies, new TV shows, Hulu Originals, and more with Hulu";
            # license = licenses.mit;
            # maintainers = teams.kodi.members ++ [ maintainers.pks ];
          };
        }
        {
          pname = "max";
          namespace = "slyguy.max";
          version = "0.1.7";

          inherit src;

          propagatedBuildInputs = with kodiPackages; [
            signals
            inputstream-adaptive
            inputstreamhelper
            requests
            myconnpy
          ];

          meta = {
            homepage = "https://github.com/matthuisman/slyguy.addons/tree/master/slyguy.max";
            description = "Say hello to Max, the streaming platform that bundles all of HBO together with even more of your favorite movies and TV series, plus new Max Originals.";
            # license = licenses.mit;
            # maintainers = teams.kodi.members ++ [ maintainers.pks ];
          };
        }
      ];
  in {
    home.file = {
      "${datadir}/cdm/libwidevinecdm.so".source = "${widevine}/_platform_specific/linux_x64/libwidevinecdm.so";
      "${datadir}/cdm/manifest.json".source = "${widevine}/manifest.json";
    };
    programs.kodi = {
      enable = true;
      inherit datadir;
      package = pkgs.kodi.withPackages (p: with p; [jellycon netflix youtube] ++ slyguy);
      # settings = { videolibrary.showemptytvshows = "true"; };
      # addonSettings = { "service.xbmc.versioncheck".versioncheck_enable = "false"; };
      # sources = {};
    };
  };
}
