{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkPackageOption mkIf mkOption types;

  cfg = config.shanetrs.browser.chromium;
in {
  options.shanetrs.browser.chromium = {
    enable = mkEnableOption "Chromium configuration and integration";
    package = mkPackageOption pkgs "chromium" {};
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
    # TODO: Implement search engines manually
    user.programs.chromium = {
      enable = true;
      extensions = map (id: {inherit id;}) cfg.extensions;
      package = cfg.package;
    };
  };
}
