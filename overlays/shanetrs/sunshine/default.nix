{pkgs, ...}:
pkgs.master.sunshine.overrideAttrs (old: {
  patches = [./full-keyboard.patch] ++ old.patches or [];
})
