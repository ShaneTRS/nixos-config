{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  udev,
  fuse,
  libclang,
  lib,
  rev ? "b9b4d1a07b3d56041208ffdfee884d195e7cbd51",
  hash ? "sha256-eatTqd7A8ZQ7+CeEgGE8J7OAILCXshgq1GUm/Byeeok=",
  cargoHash ? "sha256-5+A73HyCgyFy2gHpCbZV+Tlx5rUpUkLGVPxYvDEwVmc=",
  ...
}:
rustPlatform.buildRustPackage rec {
  pname = "vuinputd";
  version = rev;

  src = fetchFromGitHub {
    owner = "joleuger";
    repo = pname;
    inherit rev hash;
  };

  nativeBuildInputs = [pkg-config rustPlatform.bindgenHook];
  buildInputs = [udev fuse libclang];

  inherit cargoHash;
  postInstall = ''
    mkdir -p $out/opt/vuinputd/bin
    install -D {$src/vuinputd/udev,$out/lib/udev/rules.d}/90-vuinputd-protect.rules
    install -D {$src/vuinputd/udev,$out/lib/udev/hwdb.d}/90-vuinputd.hwdb
    shopt -s extglob
    mv $out/bin/!(vuinputd) $out/opt/vuinputd/bin
  '';

  meta = {
    description = "container-safe mediation daemon for /dev/uinput";
    homepage = "https://github.com/joleuger/vuinputd";
    license = lib.licenses.mit;
    mainProgram = pname;
    maintainers = [];
  };
}
