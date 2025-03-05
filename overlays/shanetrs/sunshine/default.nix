{
  pkgs,
  lib,
  ...
}:
with pkgs; let
  inherit (lib) lists;
in
  sunshine.overrideAttrs (old: rec {
    patches = [./disable-audio.patch ./full-keyboard.patch] ++ old.patches or [];
    buildInputs = lists.remove boost old.buildInputs ++ [boost185 nodePackages.npm];
    cmakeFlags = ["-DBUILD_DOCS=0" "-DBOOST_USE_STATIC=0"] ++ old.cmakeFlags or [];
    src = fetchFromGitHub {
      owner = "LizardByte";
      repo = "Sunshine";
      rev = "aa2cf8e5a9266d53b0e3ac2d7255b6854dfb574f";
      sha256 = "sha256-3x2b2WYFkrez6g0qGb+SJqCilcp2yTqu85wrtyJZtBI=";
      fetchSubmodules = true;
    };
  })
