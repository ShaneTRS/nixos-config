{
  pkgs,
  version ? "7.1.9.2516",
  hash ? "sha256-FjqDU7HskfQkZlgLhT/gMdl9YHRnaNlwvxBUYdLlock=",
  ...
}: let
  inherit (builtins) replaceStrings;
  fhs = pkgs.buildFHSEnv {
    name = "alchemy-fhs";
    targetPkgs = pkgs: (with pkgs; [
      alsa-lib
      at-spi2-atk
      cairo
      cups
      dbus
      expat
      fontconfig
      gamemode
      glib
      libdrm
      libgbm
      libGL
      libx11
      libxcb
      libxkbcommon
      livekit-libwebrtc
      nspr
      nss
      pango
      pulseaudio
      systemd
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
    ]);
    multiPkgs = pkgs: [];
  };
in
  with pkgs;
    stdenvNoCC.mkDerivation rec {
      pname = "alchemy-viewer";
      inherit version;
      _tarball = "Alchemy_Beta_${replaceStrings ["."] ["_"] version}_x86_64";
      nativeBuildInputs = [makeWrapper zstd];
      meta.mainProgram = pname;
      sourceRoot = ".";
      installPhase = ''
        mkdir -p $out/bin $out/share/applications $out/share/icons/hicolor/256x256/apps $out/opt/alchemy
        cp --no-preserve=all -r ${_tarball}/. $out/opt/alchemy
        cp ${desktopItem}/share/applications/* $out/share/applications
        chmod +x $out/opt/alchemy -R
        ln -s $out/opt/alchemy/alchemy_icon.png $out/share/icons/hicolor/256x256/apps/alchemy-viewer.png
        makeWrapper ${lib.getExe fhs} $out/bin/${meta.mainProgram} \
          --prefix LD_LIBRARY_PATH : "$out/opt/alchemy/lib:$out/opt/alchemy/bin/llplugin" \
          --add-flags "$out/opt/alchemy/alchemy"
      '';
      desktopItem = makeDesktopItem {
        name = pname;
        desktopName = "Alchemy Viewer";
        genericName = "Second Life Viewer";
        categories = ["Game" "Simulation"];
        comment = "Client for the On-line Virtual World, Second Life";
        icon = "alchemy-viewer";
        exec = "alchemy-viewer";
      };
      src = fetchurl {
        url = "https://github.com/AlchemyViewer/Alchemy/releases/download/${version}-beta/${_tarball}.tar.zst";
        inherit hash;
      };
    }
