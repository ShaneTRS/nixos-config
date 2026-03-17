{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) elem;
  inherit (lib) mkEnableOption mkIf mkOption mkPackageOption types;
  cfg = config.shanetrs.programs.vscode;
in {
  options.shanetrs.programs.vscode = {
    enable = mkEnableOption "VSCode configuration and integration";
    features = mkOption {
      type = types.listOf (types.enum ["nix" "rust"]);
      default = ["nix" "rust"];
    };
    package = mkPackageOption pkgs "vscodium" {};
    extensions = mkOption {
      type = types.listOf types.package;
      default = with pkgs.vscode-extensions;
        [usernamehw.errorlens tamasfe.even-better-toml]
        ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "codeium";
            publisher = "Codeium";
            version = "1.9.18";
            sha256 = "sha256-a20ALzOKBkgAPN6dyemOVYv1lGRddsdQSI9vwl1uOn0=";
          }
        ];
    };
  };

  home = mkIf cfg.enable {
    home.packages = with pkgs; [
      (mkIf (elem "nix" cfg.features) nixd)
    ];
    programs.vscode = {
      inherit (cfg) enable package;
      profiles.default.extensions = with pkgs.vscode-extensions;
        [
          (mkIf (elem "nix" cfg.features) kamadorueda.alejandra)
          (mkIf (elem "nix" cfg.features) jnoortheen.nix-ide)
          (mkIf (elem "nix" cfg.features) timonwong.shellcheck)
          (mkIf (elem "rust" cfg.features) rust-lang.rust-analyzer)
          (mkIf (elem "rust" cfg.features) serayuzgur.crates)
        ]
        ++ (
          if (elem "rust" cfg.features)
          then
            pkgs.vscode-utils.extensionsFromVscodeMarketplace [
              {
                name = "rust-syntax";
                publisher = "dustypomerleau";
                version = "0.6.1";
                sha256 = "sha256-o9iXPhwkimxoJc1dLdaJ8nByLIaJSpGX/nKELC26jGU=";
              }
            ]
          else []
        );
    };
  };
}
