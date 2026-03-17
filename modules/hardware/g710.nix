{
  config,
  lib,
  pkgs,
  machine,
  ...
}: let
  inherit (lib) getExe mkEnableOption mkIf mkPackageOption mkOption optionalString types;
  pcfg = config.shanetrs.hardware;
  cfg = pcfg.drivers.g710;
in {
  options.shanetrs.hardware.drivers.g710 = {
    enable = mkEnableOption "Logitech G710 driver installation and configuration";
    package = mkPackageOption pkgs.shanetrs "sidewinderd" {};
    user = mkOption {
      type = types.str;
      default = machine.user;
    };
    captureDelays = mkOption {
      type = types.bool;
      default = true;
    };
    pidFile = mkOption {
      type = types.str;
      default = "/var/run/sidewinderd.pid";
    };
    encryptedWorkDir = mkOption {
      type = types.bool;
      default = false;
    };
    workDir = mkOption {
      type = types.nullOr types.str;
      default = null; # "/home/${machine.user}/.local/share/sidewinderd"
    };
  };

  nixos = mkIf (pcfg.enable && cfg.enable) {
    warnings = mkIf (config.shanetrs.desktop.keymap.enable) ["sidewinderd doesn't properly record macros when xremap is running!"];
    environment.etc."sidewinderd.conf".text = with cfg; ''
      user = "${user}";
      capture_delays = ${
        if captureDelays
        then "true"
        else "false"
      };
      pid-file = "${pidFile}";
      encrypted_workdir = ${
        if encryptedWorkDir
        then "true"
        else "false"
      };
      ${optionalString (workDir != null) ''workdir = "${workDir}";''}
    '';
    systemd.services.sidewinderd = {
      script = getExe cfg.package;
      wantedBy = ["multi-user.target"];
    };
  };
}
