{
  moonlight-qt,
  fetchFromGitHub,
  rev ? "2e9fbecfea388ba762ffce93ceaecc6d76f9fbba",
  hash ? "sha256-zOnXNbu2KtCHKiB9BiKSstJcWWvzGrmBTfArRFW94pI=",
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
