{
  moonlight-qt,
  fetchFromGitHub,
  rev ? "ca7d61f5281f0aa820ca0f4f3307b06c4f0d257d",
  hash ? "sha256-qh/y4yASgoEwyGPssyBaBc6eFS6mPgXr2uDG5RRNqjk=",
  ...
}:
moonlight-qt.overrideAttrs (old: {
  src = fetchFromGitHub {
    owner = "moonlight-stream";
    repo = old.pname;
    inherit hash rev;
    fetchSubmodules = true;
  };
  patches = [./full-keyboard.patch];
})
