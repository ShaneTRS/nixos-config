{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  udev,
  fuse,
  libclang,
  lib,
  rev ? "aea990946de936a075cd42458c2988372b952210",
  hash ? "sha256-dOb4Sq2nInLK02DJlXmO/9mn08C6C1h7FbvIxmU83dw=",
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

  patches = [./fuse2.patch];
  cargoHash = "sha256-nJw9bRh6Yn9g1H5SeoT6zxgZLCqV3AtAs9gMfE+P+CU=";
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
