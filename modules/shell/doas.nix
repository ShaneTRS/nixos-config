{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption mkPackageOption types;
  cfg = config.shanetrs.shell;
  enabled = cfg.enable && cfg.doas.enable;
in {
  options.shanetrs.shell.doas = {
    enable = mkEnableOption "Custom configuration for doas";
    package = mkPackageOption pkgs "doas" {};
    noPassCmds = mkOption {
      type = types.listOf types.str;
      default = [];
    };
    extraRules = mkOption {
      type = types.listOf types.attrs;
      default = [
        {
          groups = ["wheel"];
          keepEnv = true;
          persist = true;
        }
      ];
    };
  };

  config = mkIf enabled {
    shanetrs.shell.doas.noPassCmds = ["true"];
    environment.systemPackages = with pkgs; [doas-sudo-shim];
    security = {
      sudo.enable = false;
      doas = {
        enable = true;
        extraRules =
          cfg.doas.extraRules
          ++ map (cmd: {
            users = [config.tundra.user];
            keepEnv = true;
            noPass = true;
            inherit cmd;
          })
          cfg.doas.noPassCmds;
      };
    };
  };
}
