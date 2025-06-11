# TigerVNC with the following patches
# - x264 encoding
# - Reduced polling delay
{pkgs, ...}:
with pkgs;
  tigervnc.overrideAttrs (old: {
    buildInputs = [ffmpeg] ++ old.buildInputs or [];
    cmakeFlags = ["-DENABLE_H264=true"] ++ old.cmakeFlags or [];
    patches = [./rapid-polling.patch] ++ old.patches or [];
  })
