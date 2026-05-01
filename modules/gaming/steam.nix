{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkPackageOption mkOption types mkIf;
  cfg = config.shanetrs.gaming.steam;
  opt = options.shanetrs.gaming.steam;
in {
  options.shanetrs.gaming = {
    steam = {
      enable = mkEnableOption "Steam configuration and installation";
      package = mkPackageOption pkgs "steam" {};
      protontricks = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        package = mkPackageOption pkgs "protontricks" {};
      };
      extraCompatPackages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [proton-ge-bin];
      };
      extraPackages = mkOption {
        type = types.listOf types.package;
        default = [];
      };
    };
  };

  config = mkIf cfg.enable {
    shanetrs.gaming.steam = {
      extraCompatPackages = opt.extraCompatPackages.default;
      extraPackages = opt.extraPackages.default;
    };
    programs.steam = {
      inherit (cfg) enable package extraCompatPackages extraPackages;
      remotePlay.openFirewall = true; # 27031..27036
      dedicatedServer.openFirewall = true; # 27015
      protontricks = {inherit (cfg.protontricks) enable package;};
      localNetworkGameTransfers.openFirewall = true; # 27040
    };
  };
}
