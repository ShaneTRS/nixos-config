{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) getExe mkEnableOption mkIf mkOption types;
  inherit (pkgs) symlinkJoin writeShellScriptBin;
  cfg = config.shanetrs.programs.discord;
in {
  options.shanetrs.programs.discord = {
    enable = mkEnableOption "Discord configuration and integration";
    branch = mkOption {
      type = types.enum ["stable" "canary" "ptb"];
      default = "canary";
    };
    mods = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      openasar = mkOption {
        type = types.bool;
        default = true;
      };
      provider = mkOption {
        type = types.enum ["equicord" "moonlight" "vencord"];
        default = "equicord";
      };
    };
    package = mkOption {
      type = types.package;
      default = let
        branches = with pkgs; {
          stable = discord;
          canary = discord-canary;
          ptb = discord-ptb;
        };
        m = cfg.mods;
      in
        branches.${cfg.branch}.override {
          withOpenASAR = m.enable && m.openasar;
          withEquicord = m.enable && m.provider == "equicord";
          withMoonlight = m.enable && m.provider == "moonlight";
          withVencord = m.enable && m.provider == "vencord";
        };
    };
  };

  config = mkIf cfg.enable {
    tundra.packages = [
      (symlinkJoin {
        name = "discord-wrapped";
        paths = [
          cfg.package
          (writeShellScriptBin "discord" ''
            pre_exec="$(date +%s)"
            "${getExe cfg.package}"
            [ $(($(date +%s) - pre_exec)) -lt 3 ] && exec "${
              getExe (cfg.package.override {withOpenASAR = false;})
            }"
          '')
        ];
        postBuild = ''
          desktopFile=$(readlink -f $out/share/applications/discord*.desktop)
          rm $out/share/applications
          mkdir -p $out/share/applications
          sed 's:Exec=.*:Exec=discord:' $desktopFile > $out/share/applications/discord.desktop
        '';
      })
    ];
  };
}
