{ config, functions, machine, pkgs, lib, ... }:
let
  inherit (lib) getExe;
  inherit (pkgs) writeShellApplication;
in {
  sops.templates.ddclient.content = let
    cfg = config.services.ddclient;
    boolYN = bool: if bool then "YES" else "NO";
  in ''
    cache=/var/lib/ddclient/ddclient.cache
    foreground=YES
    use=${cfg.use}
    protocol=${cfg.protocol}
    server=${cfg.server}
    ssl=${boolYN cfg.ssl}
    wildcard=YES
    quiet=${boolYN cfg.quiet}
    verbose=${boolYN cfg.verbose}

    login=${config.sops.placeholder."noip/user"}
    password=${config.sops.placeholder."noip/pass"}
    ${config.sops.placeholder."noip/domains"}
  '';

  services.ddclient = {
    use = "web, web=ifconfig.so/";
    interval = "3h";
    protocol = "noip";
    server = "dynupdate.no-ip.com";
    configFile = config.sops.templates.ddclient.path;
  };
  systemd.services = {
    zerotierone.preStart = ''
      for netId in $(cat ${functions.configs "zerotier"}); do
        touch "/var/lib/zerotier-one/networks.d/$netId.conf"
      done
    '';
    podman-autostart = {
      environment.LOGGING = "--log-level=info";
      serviceConfig = {
        RemainAfterExit = true;
        ExecStart = getExe (writeShellApplication {
          name = "podman-autostart.start";
          runtimeInputs = with pkgs; [ coreutils podman ];
          text = ''
            set +o errexit
            mkdir /tmp/1050368e08b494751a7fccc79f422a89 # Discord Bot
            mkdir -p "/home/${machine.user}/Containers/.shanetrs/.podman-autostart"
            touch ps

            pids=$(cat ps)
            # shellcheck disable=SC2068
            for i in ''${pids[@]}; do
              podman "$LOGGING" start "$i" || (
                sleep 2
                podman "$LOGGING" start "$i"
              )
            done
            exit 0
          '';
        });
        ExecStop = getExe (writeShellApplication {
          name = "podman-autostart.stop";
          runtimeInputs = with pkgs; [ coreutils podman ];
          text = ''
            set +o errexit
            podman container ps --filter restart-policy=unless-stopped -q |
              paste -sd' ' > "ps";
            podman "$LOGGING" stop --all --ignore
          '';
        });
        Restart = "on-failure";
        RestartSec = 5;
        Type = "oneshot";
        User = machine.user;
        WorkingDirectory = "/home/${machine.user}/Containers/.shanetrs/.podman-autostart";
      };
      wantedBy = [ "network-online.target" ];
      after = [ "network-online.target" ];
    };
  };

  systemd.user.services.keynav = {
    serviceConfig.ExecStart = "${getExe pkgs.keynav}";
    wantedBy = [ "graphical-session.target" ];
  };
}
