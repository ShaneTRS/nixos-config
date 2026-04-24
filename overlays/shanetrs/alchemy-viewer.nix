{
  buildFHSEnv,
  lib,
  alsa-lib,
  at-spi2-atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  gamemode,
  glib,
  libdrm,
  libgbm,
  libGL,
  libx11,
  libxcb,
  libxkbcommon,
  livekit-libwebrtc,
  nspr,
  nss,
  pango,
  pulseaudio,
  systemd,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  stdenvNoCC,
  makeWrapper,
  makeDesktopItem,
  fetchurl,
  zstd,
  version ? "7.1.9.2516",
  hash ? "sha256-FjqDU7HskfQkZlgLhT/gMdl9YHRnaNlwvxBUYdLlock=",
  ...
}: let
  inherit (builtins) replaceStrings;
in
  stdenvNoCC.mkDerivation rec {
    pname = "alchemy-viewer";
    inherit version;
    nativeBuildInputs = [makeWrapper zstd];
    src = fetchurl {
      url = "https://github.com/AlchemyViewer/Alchemy/releases/download/${version}-beta/Alchemy_Beta_${replaceStrings ["."] ["_"] version}_x86_64.tar.zst";
      inherit hash;
    };
    fhs = buildFHSEnv {
      name = "alchemy-fhs";
      targetPkgs = pkgs: [
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
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxrandr
      ];
      multiPkgs = pkgs: [];
    };
    desktopItem = makeDesktopItem {
      name = pname;
      desktopName = "Alchemy Viewer";
      genericName = "Second Life Viewer";
      categories = ["Game" "Simulation"];
      exec = meta.mainProgram;
      comment = meta.description;
      icon = pname;
    };
    installPhase = ''
      mkdir -p $out/{bin,opt,share/icons/hicolor/256x256/apps}
      cp -r . $out/opt/alchemy
      ln -s $out/opt/alchemy/alchemy_icon.png $out/share/icons/hicolor/256x256/apps/${pname}.png
      install -D {${desktopItem},$out}/share/applications/${pname}.desktop
      makeWrapper ${lib.getExe fhs} $out/bin/${meta.mainProgram} \
        --prefix LD_LIBRARY_PATH : "$out/opt/alchemy/lib:$out/opt/alchemy/bin/llplugin" \
        --add-flags "$out/opt/alchemy/alchemy"
    '';
    meta = {
      homepage = "https://www.alchemyviewer.org/";
      changelog = "https://github.com/AlchemyViewer/Alchemy/releases";
      description = "Client for the On-line Virtual World, Second Life";
      longDescription = "Alchemy is an openmetaverse compatible viewer striving to be at the forefront of stability, performance, and technological advancement in the open-source metaverse viewer field.";
      mainProgram = pname;
    };
  }
