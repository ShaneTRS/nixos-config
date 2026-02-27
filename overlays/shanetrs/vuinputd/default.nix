{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  udev,
  fuse,
  libclang,
  lib,
  rev ? "4c4fefb0c6590ec1f273fa80e82d090539033523",
  hash ? "sha256-zqMLi0sHozb4oMS4lndCOzFB+wuX8ehvjDOaQx8wraU=",
  ...
}:
rustPlatform.buildRustPackage (finalAttrs: rec {
  pname = "vuinputd";
  version = rev;

  src = fetchFromGitHub {
    owner = "joleuger";
    repo = pname;
    inherit rev hash;
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
