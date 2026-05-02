{
  lib,
  buildDotnetModule,
  dotnetCorePackages,
  fetchurl,
  ffmpeg,
  glew,
  gtk3,
  icu,
  libgdiplus,
  libGL,
  libice,
  libsm,
  libsoundio,
  libx11,
  libxcursor,
  libxext,
  libxi,
  libxrandr,
  openal,
  pulseaudio,
  SDL2,
  SDL2_mixer,
  sndio,
  stdenvNoCC,
  udev,
  unzip,
  vulkan-loader,
  wrapGAppsHook3,
  version ? "1.3.277",
  versionFirm ? "22.1.0",
  hash ? "sha256-oPULYKVPvHWtsj92B3fyqiFKy2ieCEUZRbNFsJx1O7Y=",
  hashFirm ? "sha256-2M1yhpqTy/e46c6vE12HYPH/iqoAGiwCkyENyVjS+zQ=",
  hashKeys ? "sha256-Sh9uY8Sg0POF7OkNiF1T/r1lSXQq1k79ob9yHTozZCk=",
  dotnetRuntime ? dotnetCorePackages.runtime_10_0,
  dotnetSdk ? dotnetCorePackages.sdk_10_0,
  nugetDeps ? ./deps.json,
  ...
}:
(buildDotnetModule rec {
  pname = "ryujinx";
  inherit version;
  src = fetchurl {
    url = "https://git.ryujinx.app/projects/Ryubing/archive/Canary-${version}.tar.gz";
    hash = hash;
  };
  nativeBuildInputs = [wrapGAppsHook3];
  enableParallelBuilding = false;
  runtimeDeps = [
    ffmpeg
    glew
    gtk3
    icu
    libgdiplus
    libGL
    libice
    libsm
    libsoundio
    libx11
    libxcursor
    libxext
    libxi
    libxrandr
    openal
    pulseaudio
    SDL2
    SDL2_mixer
    sndio
    udev
    vulkan-loader
  ];
  dotnet-sdk = dotnetSdk;
  dotnet-runtime = dotnetRuntime;
  inherit nugetDeps;
  projectFile = "Ryujinx.sln";
  testProjectFile = "src/Ryujinx.Tests/Ryujinx.Tests.csproj";
  dotnetFlags = ["/p:ExtraDefineConstants=DISABLE_UPDATER%2CFORCE_EXTERNAL_BASE_DIR"];
  executables = ["Ryujinx"];
  makeWrapperArgs = ["--set SDL_VIDEODRIVER x11"];
  preInstall = ''
    mkdir -p $out/lib/sndio-6
    ln -s ${sndio}/lib/libsndio.so $out/lib/sndio-6/libsndio.so.6
  '';
  preFixup = ''
    mkdir -p $out/share/{applications,icons/hicolor/scalable/apps,mime/packages}
    pushd distribution/linux
    sed 's:Exec=[^ ]*:Exec=ryujinx:' ./Ryujinx.desktop > $out/share/applications/Ryujinx.desktop
    install -D ./mime/Ryujinx.xml $out/share/mime/packages/Ryujinx.xml
    install -D ../misc/Logo.svg   $out/share/icons/hicolor/scalable/apps/Ryujinx.svg
    popd
    mv $out/bin/Ryujinx $out/bin/ryujinx
  '';
  meta = {
    homepage = "https://ryujinx.app";
    changelog = "https://git.ryujinx.app/ryubing/ryujinx/-/wikis/changelog";
    description = "Experimental Nintendo Switch Emulator written in C# (community fork of Ryujinx)";
    license = lib.licenses.mit;
    platforms = ["x86_64-linux"];
    mainProgram = "ryujinx";
  };
})
// {
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
