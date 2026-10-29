{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkPackageOption mkOption types mkIf;
  pcfg = config.shanetrs.gaming;
  cfg = pcfg.steam;
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
        default = with pkgs; [pulseaudio shanetrs.steamos-shim];
      };
    };
  };

  config = mkIf cfg.enable {
    shanetrs.gaming.steam = {
      extraCompatPackages = opt.extraCompatPackages.default;
      extraPackages = opt.extraPackages.default;
    };
    programs.steam = {
      inherit (cfg) enable extraCompatPackages extraPackages;
      package =
        if pcfg.mangohud.enable
        then
          cfg.package.override {
            extraEnv = {
              MANGOHUD = "1";
              MANGOHUD_DLSYM = "1";
            };
          }
        else cfg.package;
      remotePlay.openFirewall = true; # 27031..27036
      dedicatedServer.openFirewall = true; # 27015
      protontricks = {inherit (cfg.protontricks) enable package;};
      localNetworkGameTransfers.openFirewall = true; # 27040
    };
  };
}
