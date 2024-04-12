{ config, lib, functions, pkgs, settings, ... }:
let inherit (lib) mkForce mkIf mkOverride;
in {
  imports = map (file: "${./.}/${file}") (builtins.filter (x: x != "default.nix")
    (builtins.attrNames (builtins.readDir ./.))); # Import all modules in this directory (except self)
  boot = {
    initrd.availableKernelModules = [ "ata_piix" "ohci_pci" "ehci_pci" "ahci" "sd_mod" "sr_mod" ];
    kernelModules = [ "v4l2loopback" ]; # Allow using cameras
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    tmp.useTmpfs = mkOverride 900 true; # Use RAM disk for /tmp
  };
  environment.systemPackages = with pkgs; [ git nixVersions.nix_2_19 ];
  hardware = mkOverride 900 {
    pulseaudio.enable = false;
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
  };
  networking.networkmanager.enable = mkOverride 900 true;
  services = {
    earlyoom.enable = mkOverride 900 true;
    openssh.enable = mkOverride 900 true;
    udev.extraRules = ''
      KERNEL=="cpu_dma_latency", GROUP="realtime"
    '';
  };
  security.pam.loginLimits = mkOverride 900 [
    {
      domain = "@realtime";
      item = "rtprio";
      value = 99;
    }
    {
      domain = "@realtime";
      item = "memlock";
      value = "unlimited";
    }
    {
      domain = "@realtime";
      item = "nice";
      value = -20;
    }
  ];
  time.timeZone = mkOverride 900 "America/Phoenix";
  users = {
    mutableUsers = mkOverride 900 false;
    groups.realtime = mkOverride 900 { };
  };
  home-manager.users.${settings.user} = {
    home.file = {
      ".ssh" = let attempt = builtins.tryEval (functions.configs ".ssh");
      in mkIf attempt.success (mkOverride 900 {
        recursive = true;
        source = attempt.value;
      });
    };
    programs = {
      git = mkOverride 900 {
        enable = true;
        userEmail = "${settings.user}@${settings.hostname}";
        userName = settings.user;
        extraConfig = {
          safe.directory = "/etc/nixos";
          credential.helper = "store";
        };
      };
      home-manager.enable = true;
      ssh = mkOverride 900 {
        enable = true;
        controlMaster = "auto";
        controlPersist = "5m";
      };
    };
  };
  systemd.services = {
    NetworkManager-wait-online.enable = false;
    nixos-upgrade.script = mkForce ''
      ${pkgs.doas}/bin/doas -u "${settings.user}" ${pkgs.bash}/bin/sh -c 'INTERACTIVE=false UPDATE=true "${functions.flake}/rebuild" switch'
    '';
  };
  system.autoUpgrade.dates = mkOverride 900 "Thu *-*-* 04:40:00"; # Once a week at Thursday, 4:40am
}
