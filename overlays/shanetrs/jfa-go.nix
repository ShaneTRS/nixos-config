{
  stdenvNoCC,
  unzip,
  fetchurl,
  version ? "0.5.1",
  hash ? "sha256-YAaAqQMJJZUpV72P+n6cDdp4ZufUoosHcpk7DCQgi3I=",
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "jfa-go";
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
    url = "https://github.com/hrfee/${pname}/releases/download/v${version}/${pname}_${version}_Linux_x86_64.zip";
    inherit hash;
  };
}
