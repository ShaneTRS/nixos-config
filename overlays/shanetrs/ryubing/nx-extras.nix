{
  fetchurl,
  stdenvNoCC,
  unzip,
  hashFirm ? "sha256-2M1yhpqTy/e46c6vE12HYPH/iqoAGiwCkyENyVjS+zQ=",
  hashKeys ? "sha256-Sh9uY8Sg0POF7OkNiF1T/r1lSXQq1k79ob9yHTozZCk=",
  versionFirm ? "22.1.0",
  ...
}: {
  firmware = stdenvNoCC.mkDerivation {
    pname = "nx-firmware";
    version = versionFirm;
    nativeBuildInputs = [unzip];
    src = fetchurl {
      url = "https://github.com/THZoria/NX_Firmware/releases/download/${versionFirm}/Firmware.${versionFirm}.zip";
      hash = hashFirm;
    };
    sourceRoot = ".";
    installPhase = ''
      mkdir -p $out
      for i in *.nca; do
        mkdir "$out/$i"
        cp $i "$out/$i/00"
      done
    '';
  };
  keys = stdenvNoCC.mkDerivation {
    pname = "nx-keys";
    version = versionFirm;
    nativeBuildInputs = [unzip];
    src = fetchurl {
      url = "https://files.prodkeys.net/ProdKeys.NET-v${versionFirm}.zip";
      hash = hashKeys;
    };
    installPhase = ''
      mkdir -p $out
      cp * $out
    '';
  };
}
