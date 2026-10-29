{
  appimageTools,
  fetchurl,
  icu,
  version ? "2.3.3",
  hash ? "sha256-tgcJJ4DYSTKfrGKklcWJfAuHgZO6iAjfNTsI9q2ampI=",
  ...
}:
appimageTools.wrapType2 rec {
  pname = "lbr-refresher";
  inherit version;
  src = fetchurl {
    url = "https://github.com/LittleBigRefresh/Refresher/releases/download/v${version}/Refresher-linux-x64.AppImage";
    inherit hash;
  };
  extraPkgs = _: [icu];
}
