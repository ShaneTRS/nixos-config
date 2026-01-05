{
  moonlight-qt,
  fetchFromGitHub,
  rev ? "5f89636ed7227442603e1cf6bfa71f9208d30518",
  hash ? "sha256-XdAXiC87TBSEOVKRzI2yOg9WRa/IkxmVZZY/+ZQUWNk=",
  ...
}:
moonlight-qt.overrideAttrs (old: {
  src = fetchFromGitHub {
    owner = "moonlight-stream";
    repo = old.pname;
    inherit hash rev;
    fetchSubmodules = true;
  };
  patches = [./always-quit.patch ./full-keyboard.patch];
})
