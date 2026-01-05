{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  udev,
  fuse,
  libclang,
  lib,
  version ? "0.3.2",
  hash ? "sha256-X9uGLz86k0RveCasi/sjBwCy5xZAcGAOQWnOYD1VZWE=",
  ...
}:
rustPlatform.buildRustPackage (finalAttrs: rec {
  pname = "vuinputd";
  inherit version;

  src = fetchFromGitHub {
    owner = "joleuger";
    repo = pname;
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
    install -D $src/vuinputd/udev/90-vuinputd-protect.rules $out/lib/udev/rules.d/90-vuinputd-protect.rules
    install -D $src/vuinputd/udev/90-vuinputd.hwdb $out/lib/udev/hwdb.d/90-vuinputd.hwdb
  '';

  meta = {
    description = "container-safe mediation daemon for /dev/uinput";
    homepage = "https://github.com/joleuger/vuinputd";
    license = lib.licenses.mit;
    mainProgram = pname;
    maintainers = [];
  };
})
