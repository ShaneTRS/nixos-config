{
  pkgs,
  version ? "0.4.2",
  hash ? "sha256-Z/HNVUljw4Sn0ObIhjdZ7I7Sidt2j8ylQI/Li4QiUdU=",
  ...
}:
with pkgs;
  appimageTools.wrapType2 rec {
    pname = "wlx-overlay-s";
    inherit version;
    src = fetchurl {
      url = "https://github.com/galister/${pname}/releases/download/v${version}/WlxOverlay-S-v${version}-x86_64.AppImage";
      inherit hash;
    };
  }
