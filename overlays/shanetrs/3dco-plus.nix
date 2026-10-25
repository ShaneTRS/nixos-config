{
  appimageTools,
  fetchurl,
  version ? "1.4.2",
  hash ? "sha256-2+AodgWgv00Y8xJBGK01mdihQH4phHS4h/OjeMDfE48=",
  ...
}:
appimageTools.wrapType2 rec {
  pname = "3dco-plus";
  inherit version;
  src = fetchurl {
    url = "https://github.com/Khyretos/3dco-plus/releases/download/v${version}/3dco+.AppImage";
    inherit hash;
  };
}
