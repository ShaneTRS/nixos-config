{ pkgs, ... }:
with pkgs;
moonlight-qt.overrideAttrs (old: { patches = [ ./full-keyboard.patch ] ++ old.patches or [ ]; })
