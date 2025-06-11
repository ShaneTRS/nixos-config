{pkgs, ...}:
with pkgs;
  zotify.overrideAttrs (old: {
    patches = [./ffmpeg-args.patch ./sanitize-filename.patch];
    postFixup =
      old.postFixup
      + ''
        wrapProgram "$out/bin/zotify" --set PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION python
      '';
  })
