{
  lib,
  buildDotnetModule,
  callPackage,
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
  udev,
  vulkan-loader,
  wrapGAppsHook3,
  version ? "1.3.338",
  hash ? "sha256-AJJYbp/P8PYCm0TYkGHF6JWSQ9+enKT63iICFodJ7Pg=",
  dotnetRuntime ? dotnetCorePackages.runtime_10_0,
  dotnetSdk ? dotnetCorePackages.sdk_10_0,
  nugetDeps ? ./deps.json,
  emuPkg ? (buildDotnetModule rec {
    pname = "ryujinx";
    inherit version;
    src = fetchurl {
      url = "https://git.ryujinx.app/projects/Ryubing/archive/Canary-${version}.tar.gz";
      inherit hash;
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
    patches = [./internal-font.patch];
    preInstall = ''
      mkdir -p $out/lib/sndio-6
      ln -s ${sndio}/lib/libsndio.so $out/lib/sndio-6/libsndio.so.6
    '';
    preFixup = ''
      mkdir -p $out/share/{applications,icons/hicolor/256x256/apps,mime/packages}
      pushd distribution/linux
      sed 's:Exec=[^ ]*:Exec=ryujinx:' ./app.ryujinx.Ryujinx.desktop > $out/share/applications/app.ryujinx.Ryujinx.desktop
      install -D ./mime/Ryujinx.xml $out/share/mime/packages/Ryujinx.xml
      install -D ../misc/Logo.png   $out/share/icons/hicolor/256x256/apps/app.ryujinx.Ryujinx.png
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
  }),
  nxExtras ? callPackage ./nx-extras.nix args,
  ...
} @ args:
emuPkg // nxExtras
