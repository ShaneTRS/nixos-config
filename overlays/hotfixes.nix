{...}: final: prev: {
  prismlauncher = prev.prismlauncher.overrideAttrs (old: {
    qtWrapperArgs = old.qtWrapperArgs or [] ++ ["--set LD_PRELOAD ${final.sdl3.lib}/lib/libSDL3.so"];
  });
  audacity = prev.audacity.overrideAttrs (old: {
    postPatch =
      old.postPatch or ""
      + ''
        substituteInPlace muse/framework/extensions/qml/Muse/Extensions/CMakeLists.txt \
          --replace-fail 'ALIAS muse::extensions_qml' 'NO_UNITY ALIAS muse::extensions_qml'
      '';
  });
}
