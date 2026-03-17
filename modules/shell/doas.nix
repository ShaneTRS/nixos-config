{
  config,
  lib,
  pkgs,
  machine,
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
      default = ["ionice" "nix-collect-garbage" "true"];
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

  nixos = mkIf enabled {
    environment.systemPackages = with pkgs; [doas-sudo-shim];
    security = {
      sudo.enable = false;
      doas = {
        enable = true;
        extraRules =
          cfg.doas.extraRules
          ++ map (cmd: {
            users = [machine.user];
            keepEnv = true;
            noPass = true;
            cmd = cmd;
          })
          cfg.doas.noPassCmds;
      };
    };
  };
}
