{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) mapAttrs;
  inherit (lib) mkEnableOption mkIf mkOverride;
  inherit (lib.tundra) getConfig mergeFormat mkIfConfig mkStrongDefault;
in {
  options.shanetrs.enable =
    mkEnableOption "Set strong defaults, such as hostname and networking";

  config = mkIf config.shanetrs.enable {
    shanetrs = {
      shell = {
        enable = mkStrongDefault true;
        doas.enable = mkStrongDefault true;
      };
      # tundra.enable = mkStrongDefault true;
    };

    boot = {
      initrd.availableKernelModules = ["ahci" "ata_piix" "ehci_pci" "nvme" "ohci_pci" "sd_mod" "sr_mod" "usbhid"];
      kernelModules = ["v4l2loopback"];
      kernelPackages = mkStrongDefault pkgs.linuxPackages_zen;
      kernelParams = ["quiet" "splash"];
      extraModulePackages = with config.boot.kernelPackages; [v4l2loopback];
      tmp.useTmpfs = mkStrongDefault true;
    };

    environment.systemPackages = with pkgs; [git];

    hardware = {
      enableRedistributableFirmware = mkStrongDefault true;
      graphics = {
        enable = mkStrongDefault true;
        enable32Bit = mkStrongDefault true;
      };
    };

    networking = {
      firewall.enable = mkStrongDefault false;
      networkmanager.enable = mkStrongDefault true;
      hostName = mkStrongDefault config.tundra.id;
    };

    nix.settings = {
      auto-optimise-store = mkStrongDefault true;
      substituters = ["https://nix-community.cachix.org"];
      trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
      trusted-users = [config.tundra.user];
      use-xdg-base-directories = mkStrongDefault true;
    };

    programs.command-not-found.enable = mkStrongDefault false;

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

    systemd.services.NetworkManager-wait-online.enable = mkStrongDefault false;

    system = {
      autoUpgrade.dates = mkStrongDefault "Thu *-*-* 04:40:00"; # Once a week at Thursday, 4:40am
      stateVersion = "23.11";
    };

    time.timeZone = mkStrongDefault "America/Phoenix";

    tundra = {
      packages = with pkgs; [gitFull openssh];
      environment.variables = {
        TUNDRA_ID = config.tundra.id;
        TUNDRA_SOURCE = config.tundra.paths.source;
      };
      filesystem = let
        cfg = config.tundra;
      in
        mapAttrs (k: v: {
          type = "recursive";
          inherit (cfg) user;
          source = "${cfg.paths.source}/user/homes/${v}";
          target = cfg.paths.home;
        }) {
          "${cfg.paths.home}:symlinkFarm user/id" = "${cfg.user}/${cfg.id}";
          "${cfg.paths.home}:symlinkFarm user/all" = "${cfg.user}/all";
          "${cfg.paths.home}:symlinkFarm global/id" = "global/${cfg.id}";
          "${cfg.paths.home}:symlinkFarm global/all" = "global/all";
        };
      home = {
        ".ssh/config".text = mkStrongDefault ''
          Host *
            ServerAliveInterval 15
            ServerAliveCountMax 3000
            ControlMaster auto
            ControlPersist 5m
        '';
        ".ssh/authorized_keys" = mkIfConfig ".ssh/authorized_keys" (x: {
          type = "execute";
          source = mergeFormat.text.concat x;
        });
        ".ssh/known_hosts" = mkIfConfig ".ssh/known_hosts" (x: {
          type = "execute";
          source = mergeFormat.text.concat x;
        });
      };
      xdg.config = {
        "git/config" = {
          type = "execute";
          source = mergeFormat.ini.default {
            credential = {
              helper = "store";
            };
            user = {
              email = "${config.tundra.user}@${config.networking.hostName}";
              name = config.tundra.user;
            };
          };
        };
      };
    };

    users = {
      allowNoPasswordLogin = mkStrongDefault true;
      mutableUsers = mkStrongDefault false;
      groups = {
        docker.members = [config.tundra.user];
        realtime.members = [config.tundra.user];
        networkmanager.members = [config.tundra.user];
      };
      users.${config.tundra.user} = {
        isNormalUser = mkStrongDefault true;
        hashedPasswordFile = mkStrongDefault (getConfig "passwd");
        extraGroups = ["wheel"];
        autoSubUidGidRange = mkStrongDefault true;
      };
    };

    virtualisation.vmVariant = {
      boot.kernelParams = ["video=Virtual-1:1920x1025@60"];
      tundra.paths.secret.key = mkStrongDefault "/tmp/shared/id_ed25519";
      users.users.${config.tundra.user} = {
        hashedPassword = mkStrongDefault "$y$jET$N7MIfVqgEUh3jVxAi6cwB0$x7AbQ95awn0HjsS8csB2JRWXm98Pdg28zp.6dfmKmT/";
        hashedPasswordFile = mkOverride 850 null;
      };
      virtualisation = {
        cores = mkStrongDefault 6;
        memorySize = mkStrongDefault 6144;
        forwardPorts = [
          {
            from = "host";
            host.port = 13022;
            guest.port = 22;
          }
        ];
      };
    };

    zramSwap = {
      enable = mkStrongDefault true;
      memoryPercent = mkStrongDefault 70;
    };
  };
}
