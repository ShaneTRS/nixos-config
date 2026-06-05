{...}: final: prev: {
  firefoxpwa-unwrapped = prev.firefoxpwa-unwrapped.overrideAttrs {
    inherit (prev.master.firefoxpwa-unwrapped) postInstall;
  };
}
