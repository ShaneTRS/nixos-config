{pkgs, ...}: {
  shanetrs = {
    enable = true;
    browser.firefox.enable = true;
    desktop = {
      enable = true;
      xfce.enable = true;
    };
    remote = {
      enable = true;
      usb.enable = true;
      role = "client";
    };
    programs.zed-editor = {
      enable = true;
      features = ["nix"];
    };
    shell.zsh.enable = true;
  };

  services.earlyoom.enable = false;
  zramSwap.enable = false;

  tundra = {
    user = "shane";
    packages = with pkgs; [shanetrs.moonlight-qt];
  };
}
