{ pkgs, ... }:
with pkgs;
rustPlatform.buildRustPackage {
  pname = "aio";
  version = "0.1.0";
  meta.mainProgram = pname;
  src = ./.;
  cargoLock.lockFile = ./server_tools/Cargo.lock;
  patchPhase = "cd server_tools";
}
