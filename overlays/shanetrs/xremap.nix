{
  pkgs,
  wm ? "x11",
  ...
}:
with pkgs;
  stdenvNoCC.mkDerivation rec {
    pname = "xremap";
    version = "0.10.8";
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
      hash = "sha256-WbRYxzdUFErkVuHfXlYRl04FnY4b7Kl1OGnC/gYtlRk=";
    };
  }
