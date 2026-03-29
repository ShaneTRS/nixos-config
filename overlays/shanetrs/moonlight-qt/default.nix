{
  moonlight-qt,
  fetchFromGitHub,
  rev ? "b6407492c7b87822f7fac3440e2bfedd2d48ed11",
  hash ? "sha256-igBLsxzMB30FlzLZVv43StKwEJmHjfWZWWoVI+Kn7oc=",
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
