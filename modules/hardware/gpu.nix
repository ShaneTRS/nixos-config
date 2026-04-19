{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkMerge mkOption types;
  cfg = config.shanetrs.hardware;
in {
  options.shanetrs.hardware.gpu = mkOption {
    type = types.enum ["intel" "nvidia" "virtualbox" null];
    default = null;
  };

  config = mkIf (cfg.gpu != null) (mkMerge [
    (mkIf (cfg.gpu == "nvidia") {
      services.xserver.videoDrivers = ["nvidia"];
      virtualisation.podman.enableNvidia = true;
      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement = {
          enable = false;
          finegrained = false;
        };
        open = false;
        # nvidiaSettings = false;
        package = config.boot.kernelPackages.nvidiaPackages.beta;
      };
    })

    (mkIf (cfg.gpu == "virtualbox") {virtualisation.virtualbox.guest.enable = true;})

    (mkIf (cfg.gpu == "intel") {
      environment.sessionVariables = {
        LIBVA_DRIVERS_PATH = "/run/opengl-driver/lib/dri";
        LIBVA_DRIVER_NAME = "iHD";
      };
      hardware.graphics.extraPackages = with pkgs; [
        intel-media-driver
        intel-compute-runtime
        vpl-gpu-rt
      ];
    })
  ]);
}
