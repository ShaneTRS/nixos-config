{ config, lib, pkgs, functions, ... }:
let
  inherit (lib) mkEnableOption mkIf mkMerge mkOption types;
  cfg = config.shanetrs.programs;
in {
  options.shanetrs.programs = {
    enable = mkEnableOption "Program configuration and integration";
    easyeffects = {
      enable = mkEnableOption "EasyEffects configuration and installation";
      package = mkOption {
        type = types.package;
        default = pkgs.easyeffects;
      };
      # TODO: Add support for adding presets not in the user configs
      # extraPresets = mkOption {
      #   type = types.anything;
      #   default = [ ];
      # };
    };
    vscode = {
      enable = mkEnableOption "VSCode configuration and integration";
      features = mkOption {
        type = types.listOf (types.enum [ "nix" "rust" ]);
        default = [ "nix" "rust" ];
      };
      package = mkOption {
        type = types.package;
        default = pkgs.vscodium;
      };
      extensions = mkOption {
        type = types.listOf types.package;
        default = with pkgs.vscode-extensions;
          [ usernamehw.errorlens tamasfe.even-better-toml ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [{
            name = "codeium";
            publisher = "Codeium";
            version = "1.9.18";
            sha256 = "sha256-a20ALzOKBkgAPN6dyemOVYv1lGRddsdQSI9vwl1uOn0=";
          }];
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.easyeffects.enable {
      programs.dconf.enable = true;
      user = {
        home.packages = [ cfg.easyeffects.package ];
        xdg.configFile."easyeffects" = {
          recursive = true;
          source = functions.configs "easyeffects";
        };
      };
    })
    (mkIf cfg.vscode.enable {
      environment.systemPackages = with pkgs; mkIf (builtins.elem "nix" cfg.vscode.features) [ nil nixfmt ];
      user = {
        programs.vscode = {
          enable = true;
          package = cfg.vscode.package;
          extensions = with pkgs.vscode-extensions;
            [
              # (mkIf (builtins.elem "nix" cfg.vscode.features) kamadorueda.alejandra)
              (mkIf (builtins.elem "nix" cfg.vscode.features) jnoortheen.nix-ide)
              (mkIf (builtins.elem "nix" cfg.vscode.features) timonwong.shellcheck)
              (mkIf (builtins.elem "rust" cfg.vscode.features) rust-lang.rust-analyzer)
              (mkIf (builtins.elem "rust" cfg.vscode.features) serayuzgur.crates)
            ] ++ (if (builtins.elem "rust" cfg.vscode.features) then
              pkgs.vscode-utils.extensionsFromVscodeMarketplace [{
                name = "rust-syntax";
                publisher = "dustypomerleau";
                version = "0.6.1";
                sha256 = "sha256-o9iXPhwkimxoJc1dLdaJ8nByLIaJSpGX/nKELC26jGU=";
              }]
            else
              [ ]);
        };
      };
    })
  ];
}
