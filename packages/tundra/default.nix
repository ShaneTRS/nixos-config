{ pkgs, ... }:
pkgs.stdenv.mkDerivation rec {
  pname = "tundra";
  version = "0.1.0";
  src = ./src;
  buildInputs = with pkgs; [ bash git ];
  meta.mainProgram = pname;
  installPhase = "cp -r $src $out";
}
