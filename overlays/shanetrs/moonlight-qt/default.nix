{pkgs, ...}:
with pkgs;
  moonlight-qt.overrideAttrs (old: {
    src = fetchFromGitHub {
      owner = "moonlight-stream";
      repo = old.pname;
      rev = "1dbdcb5279b3c2bce756e6eff3b97d3f12a38092";
      sha256 = "sha256-CLXJo513ZGa7nU+sqpyYW1XC242W8pu9rkXSY/i/Lbg=";
      fetchSubmodules = true;
    };
    patches = [./always-quit.patch ./full-keyboard.patch];
  })
