{
  pkgs,
  version ? "0.3.2",
  hash ? "sha256-X9uGLz86k0RveCasi/sjBwCy5xZAcGAOQWnOYD1VZWE=",
  ...
}:
with pkgs;
  rustPlatform.buildRustPackage (finalAttrs: {
    pname = "vuinputd";
    inherit version;

    src = fetchFromGitHub {
      owner = "joleuger";
      repo = "vuinputd";
      tag = finalAttrs.version;
      inherit hash;
    };

    nativeBuildInputs = [pkg-config rustPlatform.bindgenHook];
    buildInputs = [udev fuse libclang];

    patches = [./fuse2.patch ./always-debug.patch];
    cargoLock.lockFile = ./Cargo.lock;
    postPatch = ''
      ln -s ${./Cargo.lock} Cargo.lock
    '';
    postFixup = ''
      mkdir -p $out/lib/udev/rules.d $out/lib/udev/hwdb.d
      cp $src/vuinputd/udev/90-vuinputd-protect.rules $out/lib/udev/rules.d
      cp $src/vuinputd/udev/90-vuinputd.hwdb $out/lib/udev/hwdb.d
    '';

    meta = {
      description = "container-safe mediation daemon for /dev/uinput";
      homepage = "https://github.com/joleuger/vuinputd";
      license = lib.licenses.unlicense;
      mainProgram = "vuinputd";
      maintainers = [];
    };
  })
