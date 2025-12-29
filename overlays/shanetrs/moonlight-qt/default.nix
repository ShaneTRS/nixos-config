{pkgs, ...}:
with pkgs;
  moonlight-qt.overrideAttrs (old: {
    src = fetchFromGitHub {
      owner = "moonlight-stream";
      repo = old.pname;
      rev = "5f89636ed7227442603e1cf6bfa71f9208d30518";
      sha256 = "sha256-XdAXiC87TBSEOVKRzI2yOg9WRa/IkxmVZZY/+ZQUWNk=";
      fetchSubmodules = true;
    };
    patches = [./always-quit.patch ./full-keyboard.patch];
  })
