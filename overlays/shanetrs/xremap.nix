{
  pkgs,
  wm ? "x11",
  version ? "0.14.7",
  hash ? "sha256-X8yVua9O2gXxNWsrbZV8J2V0AZxXBOXYBM117i6Yvqc=",
  ...
}:
with pkgs;
  stdenvNoCC.mkDerivation rec {
    pname = "xremap";
    inherit version;
    buildInputs = [unzip];
    meta.mainProgram = pname;
    unpackPhase = "unzip $src";
    installPhase = ''
      mkdir -p $out/bin
      cp --no-preserve=all -r ${pname} $out/bin
      chmod +x $out/bin/${pname}
    '';
    src = fetchurl {
      url = "https://github.com/${pname}/${pname}/releases/download/v${version}/${pname}-linux-${pkgs.hostPlatform.linuxArch}-${wm}.zip";
      inherit hash;
    };
  }
