{pkgs, ...}:
with pkgs;
  moonlight-qt.overrideAttrs (old: {
    src = fetchFromGitHub {
      owner = "moonlight-stream";
      repo = old.pname;
      rev = "ab791cf4c825481be03a065e4acd3eb35eaa094d";
      sha256 = "sha256-1cieP/m+0qBg0eu6/6l/Jxz45dIjKtCWunPTXej6aWg=";
      fetchSubmodules = true;
    };
    patches = [./always-quit.patch ./full-keyboard.patch];
  })
