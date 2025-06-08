{
  pkgs,
  version ? "1.6.2",
  hash ? "sha256-nlRkNK5a0fMnq1uarPeeFI6wtvHSq4jWNW3wDriVCoY=",
  ...
}:
with pkgs; let
  inherit (lib) getExe;
in
  stdenvNoCC.mkDerivation rec {
    pname = "ryusak";
    inherit version;
    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [
      unzip
      alsa-lib
      at-spi2-atk
      cairo
      cups
      dbus
      expat
      glib
      gtk3
      libdrm
      libxkbcommon
      mesa
      nspr
      nss
      pango
      xorg.libX11
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
      xorg.libxcb
    ];
    meta.mainProgram = pname;
    unpackPhase = "${getExe unzip} $src";
    installPhase = ''
      mkdir -p $out/bin
      cp --no-preserve=all -r RyuSAK-linux-x64/. $out
      chmod +x $out -R
      ln -s $out/RyuSAK $out/bin/${meta.mainProgram}
    '';
    src = fetchurl {
      url = "https://github.com/Ecks1337/RyuSAK/releases/download/v${version}/RyuSAK-linux-x64-${version}.zip";
      inherit hash;
    };
  }
