{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) getExe mkEnableOption mkIf mkPackageOption;
  pcfg = config.shanetrs.hardware;
  cfg = pcfg.drivers.artist12;
in {
  options.shanetrs.hardware.drivers.artist12 = {
    enable = mkEnableOption "XP-Pen Artist 12 driver installation";
    package = mkPackageOption pkgs "xp-pen-deco-01-v2-driver" {}; # note: this is out of date
  };

  config = mkIf (pcfg.enable && cfg.enable) {
    environment.systemPackages = [cfg.package];
    services.udev.packages = [cfg.package];
    systemd.services.xp-pen-deco-01-v2-driver = {
      script = getExe cfg.package;
      wantedBy = ["multi-user.target"];
    };
  };
}
