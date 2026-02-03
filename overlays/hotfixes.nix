{pkgs, ...}: new: old: {
  ffmpeg-full = pkgs.unstable.ffmpeg-full.override {withShaderc = false;};
}
