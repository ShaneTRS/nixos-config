{ config, lib, functions, pkgs, machine, ... }:
let
  inherit (lib) getExe mkForce mkOverride;
  mkStrongDefault = x: mkOverride 900 x;
in {
  imports = map (file: "${./.}/${file}") (builtins.filter (x: x != "default.nix")
    (builtins.attrNames (builtins.readDir ./.))); # Import all modules in this directory (except self)
  boot = {
    initrd.availableKernelModules = [ "ata_piix" "ohci_pci" "ehci_pci" "ahci" "sd_mod" "sr_mod" ];
    kernelModules = [ "v4l2loopback" ]; # Allow using cameras
    kernelPackages = mkStrongDefault pkgs.linuxPackages_zen; # Enable zen kernel
    kernelParams = [ "quiet" "splash" ]; # Disable boot messages
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    tmp.useTmpfs = mkStrongDefault true; # Use RAM disk for /tmp
  };
  zramSwap = mkStrongDefault {
    enable = true;
    memoryPercent = 70;
  };
  environment.systemPackages = with pkgs; [ git ];
  hardware = mkStrongDefault {
    pulseaudio.enable = false;
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
  };
  networking = {
    firewall.enable = mkStrongDefault false;
    networkmanager.enable = mkStrongDefault true;
    hostName = mkStrongDefault machine.hostname;
  };
  services = {
    earlyoom.enable = mkStrongDefault true;
    openssh = {
      enable = mkStrongDefault true;
      settings = {
        TCPKeepAlive = mkStrongDefault "yes";
        ClientAliveCountMax = mkStrongDefault 3000;
        ClientAliveInterval = mkStrongDefault 15;
      };
    };
    udev.extraRules = ''
      KERNEL=="cpu_dma_latency", GROUP="realtime"
    '';
  };
  security.pam.loginLimits = [
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
  time.timeZone = mkStrongDefault "America/Phoenix";
  users = {
    mutableUsers = mkStrongDefault false;
    groups.realtime.members = [ machine.user ];
    users.${machine.user} = {
      isNormalUser = mkStrongDefault true;
      hashedPasswordFile = mkStrongDefault (functions.configs "passwd");
      extraGroups = [ "networkmanager" "wheel" ];
    };
  };
  user = {
    home.stateVersion = "23.11";
    programs = {
      git = mkStrongDefault {
        enable = true;
        userEmail = "${machine.user}@${machine.hostname}";
        userName = machine.user;
        extraConfig = {
          safe.directory = "/etc/nixos";
          credential.helper = "store";
        };
      };
      home-manager.enable = mkStrongDefault true;
      ssh = mkStrongDefault {
        enable = true;
        controlMaster = "auto";
        controlPersist = "5m";
        serverAliveCountMax = 3000;
        serverAliveInterval = 15;
      };
    };
  };
  systemd.services = {
    NetworkManager-wait-online.enable = mkStrongDefault false;
    nixos-upgrade.script = mkForce ''
      ${getExe pkgs.doas} -u "${machine.user}" ${
        getExe pkgs.bash
      } -c 'INTERACTIVE=false UPDATE=true "${functions.flake}/rebuild" switch'
    '';
  };
  system = {
    autoUpgrade.dates = mkStrongDefault "Thu *-*-* 04:40:00"; # Once a week at Thursday, 4:40am
    stateVersion = "23.11";
  };
}
