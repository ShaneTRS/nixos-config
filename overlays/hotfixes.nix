{...}: final: prev: {
  prismlauncher = prev.prismlauncher.overrideAttrs (old: {
    qtWrapperArgs = old.qtWrapperArgs or [] ++ ["--set LD_PRELOAD ${final.sdl3.lib}/lib/libSDL3.so"];
  });
}
