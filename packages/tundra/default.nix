{ pkgs, ... }:
with pkgs;
let inherit (lib) makeBinPath;
in stdenv.mkDerivation rec {
  pname = "tundra";
  version = "0.1.0";
  src = ./src;
  nativeBuildInputs = [ makeWrapper ];
  meta.mainProgram = pname;
  installPhase = ''
    cp --no-preserve=all -r $src/. $out
    chmod +x "$out/bin/tundra"
    wrapProgram "$out/bin/tundra" \
      --prefix PATH : ${makeBinPath [ dbus git libnotify ]} \
      --set-default NOTIFY_ICON "$out/share/icons/hicolor/scalable/apps/tundra-bordered.svg"
  '';
}
