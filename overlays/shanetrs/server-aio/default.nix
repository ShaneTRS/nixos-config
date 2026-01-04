{pkgs, ...}:
with pkgs;
  rustPlatform.buildRustPackage rec {
    pname = "aio";
    version = "0.2.0";
    meta.mainProgram = pname;
    src = ./.;
    cargoLock.lockFile = ./server_tools/Cargo.lock;
    patchPhase = "cd server_tools";
  }
