{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  wrapGAppsHook4,
  gtk4,
  glib,
  gst_all_1,
  webkitgtk_6_0,
  wayland,
  libx11,
  libxext,
  libxtst,
  libxscrnsaver,
  openxr-loader,
  libglvnd,
  version ? "0.6.2",
  hash ? "sha256-OT+WYvF2/msU2iNgWww6hwM+iBGcDDhYps8GUMXb4js=",
  ...
}:
stdenv.mkDerivation rec {
  pname = "sisr";
  inherit version;

  src = fetchurl {
    url = "https://github.com/Alia5/SISR/releases/download/v${version}/SISR-linux_x64-Release.tar.gz";
    inherit hash;
  };

  icon = fetchurl {
    url = "https://raw.githubusercontent.com/Alia5/SISR/v${version}/docs/SISR.svg";
    hash = "sha256-aKqSMrfyjg0zsWk9IjnM29oau66HbP1DmReixXlo5mE=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook4
  ];

  buildInputs = [
    gtk4
    glib
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    webkitgtk_6_0
    wayland
    libx11
    libxext
    libxtst
    libxscrnsaver
    openxr-loader
    stdenv.cc.cc.lib
  ];

  autoPatchelfIgnoreMissingDeps = [
    "libsteam_api.so"
    "libGLES_CM.so.1"
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 SISR $out/bin/SISR
    install -Dm755 libSDL3.so.0.5.0 $out/lib/libSDL3.so.0.5.0
    ln -s libSDL3.so.0.5.0 $out/lib/libSDL3.so.0
    ln -s libSDL3.so.0.5.0 $out/lib/libSDL3.so

    install -Dm644 $icon $out/share/icons/hicolor/scalable/apps/sisr.svg

    runHook postInstall
  '';

  appendRunpaths = ["${placeholder "out"}/lib"];

  preFixup = ''
    gappsWrapperArgs+=(
      --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [libglvnd]}:/run/opengl-driver/lib"
    )
  '';

  meta = with lib; {
    description = "Steam Input System Redirector — use Steam Input configurations system-wide, outside of Steam games";
    homepage = "https://github.com/Alia5/SISR";
    changelog = "https://github.com/Alia5/SISR/releases/tag/v${version}";
    license = licenses.gpl3Only;
    platforms = ["x86_64-linux"];
    mainProgram = "SISR";
  };
}
