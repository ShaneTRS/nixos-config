{
  pkgs,
  version ? "7.1.9.2516",
  hash ? "sha256-FjqDU7HskfQkZlgLhT/gMdl9YHRnaNlwvxBUYdLlock=",
  ...
}:
with pkgs; let
  inherit (builtins) replaceStrings;
in
  stdenvNoCC.mkDerivation rec {
    pname = "alchemy-viewer";
    inherit version;

    _tarball = "Alchemy_Beta_${replaceStrings ["."] ["_"] version}_x86_64";

    nativeBuildInputs = [autoPatchelfHook zstd];
    buildInputs = [
      SDL2
      dbus
      fontconfig
      freealut
      libGL
      libgcc
      libjpeg8
      openal
      openjpeg
      vlc
      at-spi2-atk
      cairo
      cups
      libdrm
      mesa
      nspr
      nss
      pango
      xorg.libXcomposite
      xorg.libXdamage
    ];
    meta.mainProgram = pname;

    sourceRoot = ".";
    installPhase = ''
      cp --no-preserve=all -r ${_tarball}/. $out
      chmod +x $out -R
      ln -s $out/alchemy $out/bin/${meta.mainProgram}
    '';

    src = fetchurl {
      url = "https://github.com/AlchemyViewer/Alchemy/releases/download/${version}-beta/${_tarball}.tar.zst";
      inherit hash;
    };
  }
