{ config, lib, functions, pkgs, machine, ... }:
let inherit (lib) mkForce mkIf mkOverride;
in {
  imports = map (file: "${./.}/${file}") (builtins.filter (x: x != "default.nix")
    (builtins.attrNames (builtins.readDir ./.))); # Import all modules in this directory (except self)
  boot = {
    initrd.availableKernelModules = [ "ata_piix" "ohci_pci" "ehci_pci" "ahci" "sd_mod" "sr_mod" ];
    kernelModules = [ "v4l2loopback" ]; # Allow using cameras
    kernelPackages = mkOverride 900 pkgs.linuxPackages_zen; # Enable zen kernel
    kernelParams = [ "quiet" "splash" ]; # Disable boot messages
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    tmp.useTmpfs = mkOverride 900 true; # Use RAM disk for /tmp
  };
  zramSwap = mkOverride 900 {
    enable = true;
    memoryPercent = 70;
  };
  environment.systemPackages = with pkgs; [ git ];
  hardware = mkOverride 900 {
    pulseaudio.enable = false;
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
  };
  networking = {
    firewall.enable = mkOverride 900 false;
    networkmanager.enable = mkOverride 900 true;
    hostName = machine.hostname;
  };
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
    groups.realtime.members = [ machine.user ];
    users.${machine.user} = {
      isNormalUser = true;
      hashedPasswordFile = functions.configs "passwd";
      extraGroups = [ "networkmanager" "wheel" ];
    };
  };
  user = {
    home = {
      file = {
        ".ssh" = let attempt = builtins.tryEval (functions.configs ".ssh");
        in mkIf attempt.success (mkOverride 900 {
          recursive = true;
          source = attempt.value;
        });
      };
      stateVersion = "23.11";
    };
    programs = {
      git = mkOverride 900 {
        enable = true;
        userEmail = "${machine.user}@${machine.hostname}";
        userName = machine.user;
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
      ${pkgs.doas}/bin/doas -u "${machine.user}" ${pkgs.bash}/bin/sh -c 'INTERACTIVE=false UPDATE=true "${functions.flake}/rebuild" switch'
    '';
  };
  system = {
    autoUpgrade.dates = mkOverride 900 "Thu *-*-* 04:40:00"; # Once a week at Thursday, 4:40am
    stateVersion = "23.11";
  };
}
