{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) concatMapStrings mkEnableOption mkIf mkOption mkPackageOption types;
  inherit (lib.tundra) getConfig;
  cfg = config.shanetrs.programs.zerotier-one;
in {
  options.shanetrs.programs.zerotier-one = {
    enable = mkEnableOption "ZeroTier One configuration and installation";
    package = mkPackageOption pkgs "zerotierone" {};
    joinNetworks = mkOption {
      type = types.listOf types.str;
      default = [];
    };
    joinNetworkFiles = mkOption {
      type = types.listOf types.str;
      default = let
        attempt = getConfig "zerotier";
      in
        if attempt == null
        then []
        else [attempt];
    };
  };

  config = mkIf cfg.enable {
    services.zerotierone = {
      enable = true;
      inherit (cfg) package joinNetworks;
    };
    systemd.services.zerotierone.preStart =
      concatMapStrings (x: ''
        for id in $(cat ${x}); do
          touch "/var/lib/zerotier-one/networks.d/$id.conf"
        done
      '')
      cfg.joinNetworkFiles;
  };
}
