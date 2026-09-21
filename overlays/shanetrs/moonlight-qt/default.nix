{
  moonlight-qt,
  fetchFromGitHub,
  rev ? "032529d782242e3833e0b3b147dbbf96e878e3ca",
  hash ? "sha256-LjVq38MgEqE8XSN0q5A624smk6lZ8OSx5ZvCBSLdFKs=",
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
