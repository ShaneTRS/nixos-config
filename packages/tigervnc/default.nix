# TigerVNC with the following patches
# - x264 encoding
# - Reduced polling delay
# - Faster viewport scrolling
{ pkgs, ... }:
with pkgs;
tigervnc.overrideAttrs (old: {
  buildInputs = [ ffmpeg ] ++ old.buildInputs or [ ];
  cmakeFlags = [ "-DENABLE_H264=true" ] ++ old.cmakeFlags or [ ];

  src = fetchFromGitHub {
    owner = "TigerVNC";
    repo = "tigervnc";
    rev = "90e9db2dadccec9f614e33092f3b41d82966ae74";
    sha256 = "sha256-Zuq0wUGrGHT69HGknKHgFGAbEpUirPAjVhm0H+Ofuwg=";
  };

  patches = [ ./rapid-polling.patch ./laptop-viewport.patch ] ++ old.patches or [ ];
})
