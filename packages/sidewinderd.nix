{ pkgs, ... }:
with pkgs;
stdenv.mkDerivation rec {
  pname = "sidewinderd";
  version = "638bc839d74dc9bc6dfd3375f00742662be2f8a4";
  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ libconfig systemdLibs tinyxml-2 ];
  meta.mainProgram = pname;
  postPatch = ''
    sed -i "s:DESTINATION :DESTINATION $out/:g" src/CMakeLists.txt
  '';
  src = fetchFromGitHub {
    owner = "tolga9009";
    repo = pname;
    rev = version;
    hash = "sha256-vlmL/Wz31/xAmKV5hxQ3H5eQOCZRFKbqRjRCxQn4pdo=";
  };
}
