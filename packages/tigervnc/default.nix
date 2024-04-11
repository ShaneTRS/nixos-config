# TigerVNC with the following patches
# - x264 encoding
# - Reduced polling delay
# - Faster viewport scrolling
{ pkgs, ... }:
pkgs.tigervnc.overrideAttrs (old: {
  buildInputs = with pkgs; (old.buildInputs or [ ]) ++ [ ffmpeg ];
  cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DENABLE_H264=true" ];

  src = pkgs.fetchFromGitHub {
    owner = "TigerVNC";
    repo = "tigervnc";
    rev = "90e9db2dadccec9f614e33092f3b41d82966ae74";
    sha256 = "sha256-Zuq0wUGrGHT69HGknKHgFGAbEpUirPAjVhm0H+Ofuwg=";
  };

  patches = (old.patches or [ ]) ++ [ ./rapid-polling.patch ./laptop-viewport.patch ];
})
