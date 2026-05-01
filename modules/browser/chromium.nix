{
  config,
  lib,
  options,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.shanetrs.browser.chromium;
  opt = options.shanetrs.browser.chromium;
in {
  options.shanetrs.browser.chromium = {
    enable = mkEnableOption "Chromium configuration and integration";
    extensions = mkOption {
      type = types.listOf types.str;
      default = [
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
        "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
        "kkeakohpadmbldjaiggikmnldlfkdfog" # FastStream Video Player
        "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
      ];
    };
  };

  config = mkIf cfg.enable {
    shanetrs = {
      browser.chromium.extensions = opt.extensions.default;
      desktop.mime = {
        default = {
          "application/xhtml+xml" = ["chromium.desktop"];
          "text/html" = ["chromium.desktop"];
        };
        removed = {
          "x-scheme-handler/http" = ["chromium.desktop"];
          "x-scheme-handler/https" = ["chromium.desktop"];
        };
      };
    };
    # todo: Implement search engines manually
    programs.chromium = {
      enable = true;
      inherit (cfg) extensions;
    };
  };
}
