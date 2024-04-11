{ config, lib, pkgs, settings, ... }:
let
  cfg = config.shanetrs.settings;
  inherit (lib) mkIf mkMerge mkOption types;
  # dummyCheck = {environment.systemPackages = [];};
in {
  # This is for type checking of settings
  # This is a messy solution, as types are only checked via cfg, not via settings
  # (which is how it is accessed in other modules)

  options.shanetrs.settings = {
    hostname = mkOption { type = types.str; };
    graphics = mkOption { type = types.enum [ "intel" "nvidia" "virtualbox" ]; };
    user = mkOption { type = types.str; };
  };

  config = mkMerge [
    {
      shanetrs.settings = { inherit (settings) hostname graphics user; };
      networking.hostName = cfg.hostname;
    }

    # (mkIf (cfg.example == null) dummyCheck) # This gets "eagerly" evaluated

    (mkIf (cfg.graphics == "nvidia") {
      services.xserver.videoDrivers = [ "nvidia" ];
      boot.kernelParams = [ "nvidia-drm.modeset=1" ];
      virtualisation.podman.enableNvidia = true;
      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement = {
          enable = false;
          finegrained = false;
        };
        open = false;
        nvidiaSettings = false;
        package = config.boot.kernelPackages.nvidiaPackages.beta;
      };
    })

    (mkIf (cfg.graphics == "virtualbox") {
      virtualisation.virtualbox.guest = {
        enable = true;
        x11 = true;
      };
      home-manager.users.${cfg.user}.xsession = {
        enable = true;
        # This is a workaround for a NixOS option bug, I believe
        profileExtra = ''
          VBoxClient --clipboard
          VBoxClient --draganddrop
          VBoxClient --seamless
          VBoxClient --vmsvga
        '';
      };
    })

    (mkIf (cfg.graphics == "intel") { hardware.opengl.extraPackages = with pkgs; [ intel-media-driver ]; })
  ];
}
