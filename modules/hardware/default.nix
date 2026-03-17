{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.shanetrs.hardware.enable = mkEnableOption "Hardware driver installation and configuration";
}
