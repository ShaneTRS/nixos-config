{
  fetchFromGitHub,
  makeWrapper,
  rpcs3,
  ...
}:
rpcs3.overrideAttrs (old: {
  src = fetchFromGitHub {
    owner = "RPCS3";
    repo = "rpcs3";
    rev = "6d043f19524095945b0d29fae199b1bfba2e012f";
    postCheckout = ''
      cd $out/3rdparty
      git submodule update --init \
        fusion/fusion asmjit/asmjit yaml-cpp/yaml-cpp SoundTouch/soundtouch stblib/stb \
        feralinteractive/feralinteractive wolfssl/wolfssl
    '';
    hash = "sha256-wPLhJntVwmux6lOcST0BWnVfleTbEYd449TLFNnTRKE=";
  };
  version = "0.0.43-20306";
  nativeBuildInputs = old.nativeBuildInputs ++ [makeWrapper];
  postInstall = old.postInstall + "wrapProgram $out/bin/rpcs3 --set MANGOHUD ''";
})
