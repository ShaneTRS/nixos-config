{ config, functions, machine, pkgs, lib, ... }:
let
  inherit (functions) configs;
  inherit (lib) getExe mkIf optionalString;
  inherit (pkgs) writeShellApplication;
  jfa-go-conf = configs "jfa-go.ini";
in {
  sops.templates = let ph = config.sops.placeholder;
  in {
    jfa-go = {
      content = mkIf (jfa-go-conf != null) (builtins.replaceStrings [ "$PASSWORD" "$PUBLIC_SERVER" ] [
        ph."jellyfin/jfa-go/password"
        ph."jellyfin/jfa-go/public_server"
      ] (builtins.readFile (configs "jfa-go.ini")));
      owner = machine.user;
    };
    ddclient.content = let
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

      login=${ph."noip/user"}
      password=${ph."noip/pass"}
      ${ph."noip/domains"}
    '';
  };

  services.ddclient = {
    use = "web, web=ifconfig.so/";
    interval = "3h";
    protocol = "noip";
    server = "dynupdate.no-ip.com";
    configFile = config.sops.templates.ddclient.path;
  };
  systemd = {
    services = {
      zerotierone.preStart = ''
        for netId in $(cat ${configs "zerotier"}); do
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
      podman-autostart-check = {
        serviceConfig = {
          ExecStart = getExe (writeShellApplication {
            name = "podman-autostart-check";
            runtimeInputs = with pkgs; [ coreutils podman ];
            text = ''
              set +o errexit
              podman container ps --filter restart-policy=unless-stopped -q |
                paste -sd' ' > "ps";
            '';
          });
          Type = "oneshot";
          User = machine.user;
          WorkingDirectory = "/home/${machine.user}/Containers/.shanetrs/.podman-autostart";
        };
      };
    };
    timers = {
      podman-autostart-check = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* *:30:00";
          Unit = "podman-autostart-check.service";
        };
      };
    };
  };

  systemd.user.services = {
    keynav = {
      serviceConfig.ExecStart = "${getExe pkgs.keynav}";
      wantedBy = [ "graphical-session.target" ];
    };
    jfa-go = {
      script = ''
        sleep 15
        ${getExe pkgs.local.jfa-go} ${optionalString (jfa-go-conf != null) "-c '${config.sops.templates.jfa-go.path}'"}
      '';
      wantedBy = [ "graphical-session.target" ];
    };
  };
}
