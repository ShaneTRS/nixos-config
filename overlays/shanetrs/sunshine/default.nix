{pkgs, ...}:
with pkgs;
  sunshine.overrideAttrs (old: {
    patches = [./disable-audio.patch ./full-keyboard.patch] ++ old.patches or [];
    buildInputs = old.buildInputs ++ [nodePackages.npm];
    cmakeFlags = ["-DBUILD_DOCS=0" "-DBOOST_USE_STATIC=0"] ++ old.cmakeFlags or [];
  })
