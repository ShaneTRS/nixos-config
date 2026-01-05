{
  buildNpmPackage,
  pkg-config,
  libusb1,
  makeDesktopItem,
  electron,
  ...
}:
buildNpmPackage rec {
  pname = "schud";
  version = "1.2.0";
  src = ./.;

  npmDepsHash = "sha256-oit+dC/fN5CibmzOXjJbv5CM4XlGRdk8lYOH7O3+uxo=";
  nativeBuildInputs = [pkg-config];
  buildInputs = [libusb1];

  dontNpmBuild = true;
  makeCacheWritable = true;

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "SCHUD";
    icon = "input-gamepad";
    exec = pname;
  };

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = 1;
  postInstall = ''
    install -D {${desktopItem},$out}/share/applications/${pname}.desktop
    makeWrapper ${electron}/bin/electron $out/bin/${pname} \
      --add-flags $out/lib/node_modules/${pname}/main.js
  '';
}
