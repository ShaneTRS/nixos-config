{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (builtins) readFile;
  inherit (lib) getExe mkIf optionalAttrs optionalString;
  inherit (lib.tundra) getConfig' getConfig;
  inherit (pkgs) writeShellApplication;

  jfa-go-conf = getConfig' [] "jfa-go.ini";
in {
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
  networking.extraHosts = ''
    192.168.1.11 shanetrs.ddns.net
  '';

  tundra.secret = {
    "jfa-go.ini" = mkIf (jfa-go-conf != null) {
      text = readFile jfa-go-conf;
    };
    "ddclient.conf".text = let
      cfg = config.services.ddclient;
      boolYN = x:
        if x
        then "YES"
        else "NO";
    in ''
      cache=/var/lib/ddclient/ddclient.cache
      foreground=YES
      usev4=${cfg.usev4}
      protocol=${cfg.protocol}
      server=${cfg.server}
      ssl=${boolYN cfg.ssl}
      wildcard=YES
      quiet=${boolYN cfg.quiet}
      verbose=${boolYN cfg.verbose}

      login=%%noip.user
      password=%%noip.pass
      $%%noip.domains
    '';
  };
  services = {
    ddclient = {
      usev4 = "webv4, webv4=ifconfig.so/";
      interval = "3h";
      protocol = "noip";
      server = "dynupdate.no-ip.com";
      configFile = config.tundra.secret."ddclient.conf".target;
    };
    nix-serve = {
      enable = true;
      openFirewall = true;
      port = 5698;
      secretKeyFile = "/var/cache-priv-key.pem";
    };
  };

  security.wrappers.vuinputd = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin,cap_mknod,cap_dac_override,cap_fowner+eip";
    source = getExe pkgs.shanetrs.vuinputd;
  };

  systemd = {
    services = {
      vuinputd = {
        script = "${config.security.wrapperDir}/vuinputd --major 120 --minor 414795";
        after = ["systemd-udevd.service"];
        requires = ["systemd-udevd.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig.DeviceAllow = "char-* rwm";
      };
      podman-autostart = {
        environment.LOGGING = "--log-level=info";
        restartIfChanged = false;
        serviceConfig = {
          RemainAfterExit = true;
          ExecStart = getExe (writeShellApplication {
            name = "podman-autostart.start";
            runtimeInputs = with pkgs; [coreutils podman slirp4netns];
            text = ''
              set +o errexit
              mkdir /tmp/1050368e08b494751a7fccc79f422a89 # Discord Bot
              mkdir -p "${config.tundra.paths.home}/Containers/.shanetrs/.podman-autostart"
              touch ps

              export PATH="$PATH:/run/wrappers/bin"
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
            runtimeInputs = with pkgs; [coreutils podman];
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
          User = config.tundra.user;
          WorkingDirectory = "${config.tundra.paths.home}/Containers/.shanetrs/.podman-autostart";
        };
        wants = ["network-online.target"];
        after = ["network-online.target"];
        wantedBy = ["graphical.target"];
      };
      podman-autostart-check = {
        serviceConfig = {
          ExecStart = getExe (writeShellApplication {
            name = "podman-autostart-check";
            runtimeInputs = with pkgs; [coreutils podman];
            text = ''
              set +o errexit
              podman container ps --filter restart-policy=unless-stopped -q |
                paste -sd' ' > "ps";
            '';
          });
          Type = "oneshot";
          User = config.tundra.user;
          WorkingDirectory = "${config.tundra.paths.home}/Containers/.shanetrs/.podman-autostart";
        };
      };
    };
    timers = {
      podman-autostart-check = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "*-*-* *:30:00";
          Unit = "podman-autostart-check.service";
        };
      };
    };
    user.services = {
      shadowplay = {
        serviceConfig.ExecStart = getExe pkgs.shanetrs.shadowplay;
        wantedBy = ["graphical-session.target"];
      };
      keynav = {
        serviceConfig.ExecStart = getExe (pkgs.keynav.overrideAttrs (old: let
          attempt = getConfig "keynavrc";
        in
          optionalAttrs (attempt != null) {
            env.NIX_CFLAGS_COMPILE =
              (old.env.NIX_CFLAGS_COMPILE or "") + " -DGLOBAL_CONFIG_FILE=\"${attempt}\"";
          }));
        wantedBy = ["graphical-session.target"];
      };
      jfa-go = {
        script = ''
          sleep 15
          ${getExe pkgs.shanetrs.jfa-go} ${optionalString (jfa-go-conf != null) "-c '${config.tundra.secret."jfa-go.ini".target}'"}
        '';
        wantedBy = ["graphical-session.target"];
      };
    };
  };
}
