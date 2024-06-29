{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  pname = "tundra";
  version = "0.1.0";
  src = ./src;
  buildInputs = with pkgs; [ bash git ];
  installPhase = "cp -r $src $out";
}
