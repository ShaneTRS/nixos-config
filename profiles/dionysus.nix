{
  pkgs,
  lib,
  fn,
  ...
}: let
  inherit (builtins) listToAttrs;
  inherit (fn) configs;
  inherit (lib) mkIf;
in {
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
    programs.zed-editor = {
      enable = true;
      features = ["nix"];
    };
    shell.zsh.enable = true;
    tundra.appStores = [];
  };

  user = {
    home.packages = with pkgs; [shanetrs.moonlight-qt];
    xdg.configFile = let
      mkFile = key: let
        source = configs "xfce4/${key}.xml";
      in {
        name = "xfce4/xfconf/xfce-perchannel-xml/${key}.xml";
        value = mkIf (source != null) {inherit source;};
      };
    in
      listToAttrs (map mkFile [
        "xfce4-desktop"
        "xfce4-panel"
        "xsettings"
      ]);
  };
}
