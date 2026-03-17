{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) elem;
  inherit (lib) mkEnableOption mkIf mkOption mkPackageOption types;
  inherit (lib.tundra) resolveList;
  cfg = config.shanetrs.programs.zed-editor;
in {
  options.shanetrs.programs.zed-editor = {
    enable = mkEnableOption "Zed configuration and integration";
    features = mkOption {
      type = types.listOf (types.enum ["nix" "rust"]);
      default = ["nix" "rust"];
    };
    package = mkPackageOption pkgs "zed-editor" {};
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
    };
  };

  home = mkIf cfg.enable {
    home.packages = [
      (pkgs.symlinkJoin {
        name = "zed-editor-wrapped";
        paths = [cfg.package];
        preferLocalBuild = true;
        nativeBuildInputs = with pkgs; [makeWrapper];
        postBuild = ''
          wrapProgram $out/bin/zeditor \
          --suffix PATH : ${lib.makeBinPath (cfg.extraPackages
            ++ (with pkgs;
              resolveList [
                shanetrs.devcontainer
                gcc
                clang-tools
                package-version-server
                (mkIf (elem "nix" cfg.features) nixd)
                (mkIf (elem "nix" cfg.features) alejandra)
                (mkIf (elem "rust" cfg.features) rustup)
              ]))}
        '';
      })
    ];
  };
}
