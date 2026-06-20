{...}: final: prev: {
  firefoxpwa-unwrapped = prev.firefoxpwa-unwrapped.overrideAttrs (old: {
    postInstall = old.postInstall + "mkdir $out/lib/firefoxpwa";
  });
}
