{pkgsCross, ...}:
pkgsCross.musl64.rustPlatform.buildRustPackage rec {
  pname = "aio";
  version = "0.2.0";
  src = ./.;
  env.RUSTFLAGS = "-C target-feature=+crt-static";
  cargoLock.lockFile = ./server_tools/Cargo.lock;
  patchPhase = "cd server_tools";
  meta.mainProgram = pname;
}
