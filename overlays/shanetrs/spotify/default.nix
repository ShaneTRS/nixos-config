{spotify, ...}:
spotify.overrideAttrs (old: {
  postInstall =
    old.postInstall
      or ""
    + ''
      ln -s "${./adblock.so}" "$libdir/adblock.so"
      ln -s "${./config.toml}" "$out/share/spotify/config.toml"
      wrapProgram $out/bin/spotify --chdir "$out/share/spotify" --prefix LD_PRELOAD : "$libdir/adblock.so"
    '';
})
