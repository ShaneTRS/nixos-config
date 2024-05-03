{ config, lib, functions, pkgs, machine, ... }:
let
  inherit (lib) mkForce mkIf mkOverride;
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
    hostName = machine.hostname;
  };
  services = {
    earlyoom.enable = mkStrongDefault true;
    openssh = {
      enable = mkStrongDefault true;
      settings = {
        TCPKeepAlive = mkStrongDefault "yes";
        ClientAliveCountMax = mkStrongDefault 30;
        ClientAliveInterval = mkStrongDefault 15;
      };
    };
    udev.extraRules = ''
      KERNEL=="cpu_dma_latency", GROUP="realtime"
    '';
  };
  security.pam.loginLimits = mkStrongDefault [
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
      isNormalUser = true;
      hashedPasswordFile = functions.configs "passwd";
      extraGroups = [ "networkmanager" "wheel" ];
    };
  };
  user = {
    home = {
      file = {
        ".ssh" = let attempt = builtins.tryEval (functions.configs ".ssh");
        in mkIf attempt.success (mkStrongDefault {
          recursive = true;
          source = attempt.value;
        });
      };
      stateVersion = "23.11";
    };
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
      home-manager.enable = true;
      ssh = mkStrongDefault {
        enable = true;
        controlMaster = "auto";
        controlPersist = "5m";
        serverAliveCountMax = 30;
        serverAliveInterval = 15;
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
    autoUpgrade.dates = mkStrongDefault "Thu *-*-* 04:40:00"; # Once a week at Thursday, 4:40am
    stateVersion = "23.11";
  };
}
