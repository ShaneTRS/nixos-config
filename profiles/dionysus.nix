{ pkgs, ... }: {
  services.earlyoom.enable = false;
  zramSwap.enable = false;

  shanetrs = {
    enable = true;
    browser.firefox.enable = true;
    desktop = {
      enable = true;
      session = "xfce";
    };
    remote = {
      enable = true;
      usb.enable = true;
      role = "client";
    };
    programs.vscode = {
      enable = true;
      features = [ "nix" ];
    };
    shell.zsh.enable = true;
    tundra.appStores = [ ];
  };

  user.home.packages = with pkgs; [ local.moonlight-qt local.ml-launcher ];
}
