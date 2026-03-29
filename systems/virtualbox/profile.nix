{pkgs, ...}: {
  config.shanetrs = {
    enable = true;
    browser.firefox.enable = true;
    desktop = {
      enable = true;
      niri.enable = true;
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
    tundra.appStores = [];
  };

  nixos = {
    services.earlyoom.enable = false;
    zramSwap.enable = false;
  };

  home.home.packages = with pkgs; [shanetrs.moonlight-qt];

  machine.user = "shane";
}
