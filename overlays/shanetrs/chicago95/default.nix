{
  pkgs,
  lib,
  ...
}:
with pkgs;
  stdenvNoCC.mkDerivation rec {
    pname = "chicago95";
    version = "3.1.0";

    buildInputs = [gdk-pixbuf xfce.xfce4-panel-profiles ./import];

    src = fetchFromGitHub {
      owner = "grassmunk";
      repo = "Chicago95";
      rev = "a8bee4fd1f86c7953fecd5a0a1e96f5715c805c5";
      hash = "sha256-Mm71M909IVm8XfQCs+Lv808wSz8Dx1NxFU8t8xKmYUs=";
    };

    patches = [./whiskermenu.patch]; # Use Win95 branding

    # the Makefile is just for maintainers
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/{themes,icons,sounds,fonts}
      mv Theme/Chicago95 $out/share/themes
      mv Icons/* $out/share/icons
      mv Cursors/* $out/share/icons
      mv sounds/Chicago95 $out/share/sounds
      mv Extras/'Microsoft Windows 95 Startup Sound.ogg' $out/share/sounds/Chicago95/startup.ogg
      mv Fonts/bitmap/cronyx-cyrillic $out/share/fonts

      cp -r ${./import} $out/import
      mkdir -p $out/repo
      cp -r . $out/repo

      runHook postInstall
    '';

    meta = with lib; {
      description = "A rendition of everyone's favorite 1995 Microsoft operating system for Linux.";
      homepage = "https://github.com/grassmunk/Chicago95";
      license = with licenses; [gpl3Plus mit];
      platforms = platforms.linux;
      maintainers = [];
      mainProgram = pname;
    };
  }
