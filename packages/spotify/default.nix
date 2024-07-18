{ pkgs, ... }:
with pkgs;
spotify.overrideAttrs (old: {
  postInstall = old.postInstall or "" + ''
    ln -s "${./adblock.so}" "$libdir/adblock.so"
    ln -s "${./config.toml}" "$out/share/spotify/config.toml"
    sed -i "s:^Exec=\(.*\):Exec=bash -c 'cd \"$out/share/spotify\"; env LD_PRELOAD=$libdir/adblock.so \1':" "$out/share/applications/spotify.desktop"
  '';
})
