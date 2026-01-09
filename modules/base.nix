{
  self,
  config,
  fn,
  lib,
  machine,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOverride;
  inherit (fn) configs;
  mkStrongDefault = x: mkOverride 900 x;
in {
  options.shanetrs.enable =
    mkEnableOption "Set strong defaults, such as hostname and networking";

  config = mkIf config.shanetrs.enable {
    boot = {
      initrd.availableKernelModules = ["ahci" "ata_piix" "ehci_pci" "nvme" "ohci_pci" "sd_mod" "sr_mod" "usbhid"];
      kernelModules = ["v4l2loopback"];
      kernelPackages = mkStrongDefault pkgs.linuxPackages_zen;
      kernelParams = ["quiet" "splash"];
      extraModulePackages = with config.boot.kernelPackages; [v4l2loopback];
      tmp.useTmpfs = mkStrongDefault true;
    };

    environment = {
      sessionVariables = {
        TUNDRA_SERIAL = machine.serial;
        TUNDRA_SOURCE = machine.source;
      };
      systemPackages = with pkgs; [git];
    };

    hardware.graphics = {
      enable = mkStrongDefault true;
      enable32Bit = mkStrongDefault true;
    };

    networking = {
      firewall.enable = mkStrongDefault false;
      networkmanager.enable = mkStrongDefault true;
      hostName = mkStrongDefault machine.hostname;
    };

    nix.settings = {
      auto-optimise-store = mkStrongDefault true;
      substituters = ["https://nix-community.cachix.org"];
      trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
      trusted-users = [machine.user];
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

    shanetrs = {
      shell.doas.enable = mkStrongDefault true;
      tundra.enable = mkStrongDefault true;
    };

    systemd.services.NetworkManager-wait-online.enable = mkStrongDefault false;

    system = {
      autoUpgrade.dates = mkStrongDefault "Thu *-*-* 04:40:00"; # Once a week at Thursday, 4:40am
      stateVersion = "23.11";
    };

    time.timeZone = mkStrongDefault "America/Phoenix";

    users = {
      mutableUsers = mkStrongDefault false;
      groups = {
        docker.members = [machine.user];
        realtime.members = [machine.user];
      };
      users.${machine.user} = {
        isNormalUser = mkStrongDefault true;
        hashedPasswordFile = mkStrongDefault (configs "passwd");
        extraGroups = ["networkmanager" "wheel"];
        autoSubUidGidRange = mkStrongDefault true;
      };
    };

    home-manager = {
      useGlobalPkgs = mkStrongDefault true;
      useUserPackages = mkStrongDefault true;
    };
    user = {
      home = {
        stateVersion = "23.11";
        activation = {
          symlinkFarmHomes = with machine;
            self.inputs.home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
              set +o errexit
              cd "${source}/user/homes" || exit 1

              [ -f "$PWD/last" ] && while read -r FILE; do
                TARGET="$(realpath "$FILE")"
                FILE="''${FILE#*/}" # Strip target profile
                FILE="''${FILE#*/}" # Strip target user
                if [ -L "$HOME/$FILE" ]; then
                  run rm "$HOME/$FILE"
                fi
              done < "$PWD/last"
              rm last

              for i in "${user}/${profile}" "${user}/all" "global/${profile}" "global/all"; do
              	find "$i" -type f >> last
              done

              [ -f "$PWD/last" ] && while read -r FILE; do
                TARGET="$(realpath "$FILE")"
                FILE="''${FILE#*/}" # Strip target profile
                FILE="''${FILE#*/}" # Strip target user
                if [ ! -L "$HOME/$FILE" ]; then
                  run mkdir -p "$HOME/$(dirname "$FILE")"
                  run ln -sf "$TARGET" "$HOME/$FILE" # Replace existing files
                fi
              done < "$PWD/last"
            '';
        };
      };
      programs = {
        git = {
          enable = mkStrongDefault true;
          settings = {
            user.email = mkStrongDefault "${machine.user}@${machine.hostname}";
            user.name = mkStrongDefault machine.user;
            credential.helper = mkStrongDefault "store";
          };
        };
        home-manager.enable = mkStrongDefault true;
        ssh = {
          enable = mkStrongDefault true;
          enableDefaultConfig = mkStrongDefault false;
          matchBlocks."*" = {
            controlMaster = mkStrongDefault "auto";
            controlPersist = mkStrongDefault "5m";
            serverAliveCountMax = mkStrongDefault 3000;
            serverAliveInterval = mkStrongDefault 15;
          };
        };
      };
    };

    zramSwap = {
      enable = mkStrongDefault true;
      memoryPercent = mkStrongDefault 70;
    };
  };
}
