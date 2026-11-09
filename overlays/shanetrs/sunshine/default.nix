{
  sunshine,
  lib,
  buildNpmPackage,
  fetchzip,
  fetchFromGitHub,
  qt6,
  libappindicator,
  version ? "2026.914.233613",
  depsVersion ? "2026.910.121303",
  hash ? "sha256-HqbswLvX/UiY3nOwxSesBMqnFAF0zKP1ueE6PwDtTNs=",
  depsHash ? "sha256-1S57XfkJa+qEYQLmifWyT9ul0SASFhSk1lkk2timnOY=",
  uiHash ? "sha256-/uY+zvYxQG0Yb8kygwF48YfS+Km0bcQBW4poaqkeJXs=",
  ...
}: let
  inherit (lib) cmakeFeature remove;
in
  sunshine.overrideAttrs (old: rec {
    inherit version depsVersion;
    ffmpeg = fetchzip {
      url = "https://github.com/LizardByte/build-deps/releases/download/v${depsVersion}/Linux-x86_64-ffmpeg.tar.gz";
      hash = depsHash;
    };

    src = fetchFromGitHub {
      owner = "LizardByte";
      repo = "Sunshine";
      tag = "v${version}";
      inherit hash;
      fetchSubmodules = true;
    };
    ui = buildNpmPackage {
      inherit src version;
      pname = "sunshine-ui";
      npmDepsHash = uiHash;
      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        cp -a . "$out"/
        runHook postInstall
      '';
    };

    cmakeFlags = old.cmakeFlags or [] ++ [(cmakeFeature "FFMPEG_PREPARED_BINARIES" (toString ffmpeg))];
    dontWrapQtApps = true;
    nativeBuildInputs = [qt6.wrapQtAppsHook] ++ old.nativeBuildInputs or [];
    postFixup = ''
      wrapProgram $out/bin/sunshine "''${qtWrapperArgs[@]}"
    '';
    buildInputs = (remove libappindicator old.buildInputs) ++ [qt6.qtbase qt6.qtsvg];
    patches = [./full-keyboard.patch] ++ old.patches or [];
  })
