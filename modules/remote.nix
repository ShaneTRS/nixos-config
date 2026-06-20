{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) getExe mkEnableOption mkOrder mkPackageOption mkIf mkMerge mkOption optionalString toList types;
  inherit (lib.tundra) getConfig;
  inherit (builtins) attrNames concatStringsSep isAttrs listToAttrs match toJSON;
  cfg = config.shanetrs.remote;
in {
  options.shanetrs.remote = {
    enable = mkEnableOption "Low-latency access to a remote machine";
    role = mkOption {
      type = types.enum ["host" "client"];
      example = "host";
    };
    package = mkPackageOption pkgs.shanetrs "ml-launcher" {};
    addresses = {
      client = mkOption {
        type = types.str;
        default = "192.168.1.12";
      };
      host = mkOption {
        type = types.str;
        default = "192.168.1.11";
      };
    };
    usb = {
      enable = mkEnableOption "Forward specific USB ports over the network";
      devices = mkOption {
        type = types.str;
        example = "/sys/bus/pci/devices/0000:00:14.0/usb2/";
      };
      ports = mkOption {
        type =
          if cfg.role == "client"
          then types.listOf types.str
          else null;
        example = ["2-2" "2-4"];
      };
    };
    audio = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      sink = {
        name = mkOption {
          type = types.str;
          default = "Laptop Speakers";
        };
        priority = mkOption {
          type = types.int;
          default = 1000;
        };
      };
      source = {
        name = mkOption {
          type = types.str;
          default = "Laptop Microphone";
        };
        priority = mkOption {
          type = types.int;
          default = 1000;
        };
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      security.doas.extraRules = mkIf cfg.usb.enable [
        {
          users = [config.tundra.user];
          keepEnv = true;
          noPass = true;
          cmd = "usbip";
        }
      ];
      environment.systemPackages = [(mkIf cfg.usb.enable config.boot.kernelPackages.usbip)];
      systemd.services.usbipd = mkIf cfg.usb.enable {
        script = "${config.boot.kernelPackages.usbip}/bin/usbipd";
        wantedBy = ["default.target"];
      };
      boot.kernelModules = mkIf cfg.usb.enable ["usbip-core" "usbip-host" "vhci-hcd"];
      networking.extraHosts = ''
        ${cfg.addresses.client} shanetrs.remote.client
        ${cfg.addresses.host} shanetrs.remote.host
      '';
    }

    (mkIf (cfg.role == "client") {
      shanetrs.desktop.keymap.transforms = [
        (k: v:
          if k == "keymap" || k == "modmap"
          then
            map (x:
              if isAttrs x && match ".*-ungrab" x.name == null
              then x // {application = x.application or {} // {not = (toList x.application.not or []) ++ ["/moonlight_stream/"];};}
              else x)
            v
          else v)
      ];
      tundra = {
        packages = [cfg.package];
        xdg.config = let
          input = {
            "60-shanetrs-remote"."context.modules" = [
              {
                name = "libpipewire-module-rtp-source";
                args = {
                  "audio.channels" = 1;
                  "audio.position" = ["MONO"];
                  "sess.latency.msec" = 80;
                  "sess.ignore-ssrc" = true;
                  "sess.media" = "opus";
                  "source.ip" = "0.0.0.0";
                  "source.port" = 46601;
                  "stream.props" = {"node.name" = "shanetrs.remote.client";};
                };
              }
              {
                name = "libpipewire-module-rtp-sink";
                args = {
                  "audio.channels" = 1;
                  "audio.position" = ["MONO"];
                  "sess.media" = "opus";
                  "destination.ip" = "shanetrs.remote.host";
                  "destination.port" = 46602;
                  "stream.props" = {"node.name" = "shanetrs.remote.client-mic";};
                };
              }
            ];
          };
        in
          mkIf cfg.audio.enable (listToAttrs (map (k: {
            name = "pipewire/pipewire.conf.d/${k}.conf";
            value = {text = toJSON input.${k};};
          }) (attrNames input)));
      };

      systemd.services.usbip = mkIf cfg.usb.enable (let
        awk = getExe pkgs.gawk;
        notify-send = getExe pkgs.libnotify;
        ssh = getExe pkgs.openssh;
        su = "${pkgs.su}/bin/su";
        udevadm = "${pkgs.systemd}/bin/udevadm";
        usbip = "${config.boot.kernelPackages.usbip}/bin/usbip";
      in {
        serviceConfig.Restart = "on-failure";
        environment = {
          TARGET = "${config.tundra.user}@shanetrs.remote.host";
          PORTS = "${concatStringsSep ":" cfg.usb.ports}";
          DEVICES = toString cfg.usb.devices;
        };
        script = ''
          export XDG_RUNTIME_DIR="/run/user/$(id -u ${config.tundra.user})"
          as_user() { ${su} ${config.tundra.user} /bin/sh -c "$(printf '%q ' "$@")"; }

          notify () {
          [ "$1" == "disconnect" ] &&
            str="Disconnected port $2 from host at $3" ||
            str="Connected port $2 to host at $3";
          as_user ${notify-send} -i "network-$1" -a usb-forwarding 'USB Port Forwarding' "$str" -t 1000
          }

          until echo > "/dev/tcp/''${TARGET#*@}/22"; do sleep 1; done
          for i in $(as_user ${ssh} "$TARGET" usbip port 2>/dev/null | ${awk} -F'[: ]' '/^Port /{print $2}'); do
            detach+="doas usbip detach -p$i;"
          done
          [ -n "$detach" ] && as_user ${ssh} "$TARGET" "''${detach%:}"

          IFS=: read -ra PORTS <<< "$PORTS"
          for i in "''${PORTS[@]}"; do
            usb="$DEVICES''${i%-*}/''${i%.*}"
            [[ "$1" == *"."* ]] && usb+="/$1"
            bus=''${usb//*\/}
            while true; do
              ${udevadm} wait "$usb"
              sleep .2
              ${usbip} unbind -b"$bus" &>/dev/null || true
              ${usbip} bind -b"$bus"
              sleep .2
              as_user ${ssh} "$TARGET" doas usbip attach -r${"'"}''${SSH_CLIENT%% *}' -b"$bus"
              notify connect "$bus" "$TARGET"
              ${udevadm} wait "$usb" --removed
              notify disconnect "$bus" "$TARGET"
            done &
          done
          wait
        '';
        startLimitBurst = 32;
        wantedBy = ["default.target"];
      });
    })

    (mkIf (cfg.role == "host") {
      tundra.xdg.config = let
        input = {
          "60-shanetrs-remote"."context.modules" = [
            {
              name = "libpipewire-module-rtp-sink";
              args = {
                "audio.channels" = 1;
                "audio.position" = ["MONO"];
                "sess.media" = "opus";
                "destination.ip" = "shanetrs.remote.client";
                "destination.port" = 46601;
                "stream.props" = {
                  "media.class" = "Audio/Sink";
                  "node.description" = cfg.audio.sink.name;
                  "node.name" = "shanetrs.remote.host";
                  "priority.session" = cfg.audio.sink.priority;
                };
              };
            }
            {
              name = "libpipewire-module-rtp-source";
              args = {
                "audio.channels" = 1;
                "audio.position" = ["MONO"];
                "sess.latency.msec" = 0;
                "sess.ignore-ssrc" = true;
                "sess.media" = "opus";
                "source.ip" = "0.0.0.0";
                "source.port" = 46602;
                "stream.props" = {
                  "media.class" = "Audio/Source";
                  "node.description" = cfg.audio.source.name;
                  "node.name" = "shanetrs.remote.client-mic";
                  "priority.session" = cfg.audio.source.priority;
                };
              };
            }
          ];
        };
      in
        mkIf cfg.audio.enable (listToAttrs (map (k: {
          name = "pipewire/pipewire.conf.d/${k}.conf";
          value = {text = toJSON input.${k};};
        }) (attrNames input)));
      systemd.user.services.vncserver = let
        attempt = getConfig ".vnc/passwd";
        vncserver = type: "${getExe pkgs.shanetrs.not-nice} ${pkgs.tigervnc}/bin/${type}0vncserver";
        passwordFlag = optionalString (attempt != null) ''-PasswordFile "${attempt}"'';
        sharedFlags = "${passwordFlag} -FrameRate 60 -CompareFB 2";
        preAuthScript = ''
          {
            until echo > /dev/tcp/127.0.0.1/5900; do sleep 1; done
            until [ -n "$XAUTHORITY" ]; do
              for i in "$HOME/.Xauthority" "/run/user/$(id -u $${config.tundra.user})/xauth_"*; do
                if [ -e "$i" ]; then export XAUTHORITY="$i"; break; fi
              done
              sleep 1
            done
            coproc VIEWER { exec ${getExe pkgs.tigervnc} ${passwordFlag} 127.0.0.1:5900 2>&1; }
            sed /DesktopWindow/q <& "''${VIEWER[0]}"
            [ -z "$VIEWER_PID" ] || kill -9 "$VIEWER_PID"
          } &
        '';
        usingWayland = config.shanetrs.desktop.type == "wayland";
      in {
        serviceConfig.Restart = "on-failure";
        environment = {
          DISPLAY = ":0";
          WAYLAND_DISPLAY = "wayland-0";
        };
        startLimitBurst = 32;
        # todo: make this less of a hack
        script = ''
          ${optionalString usingWayland preAuthScript}
          ${
            if usingWayland
            then "${vncserver "w"} ${sharedFlags}"
            else "${vncserver "x"} Geometry=2732x1536 ${sharedFlags} -PollingCycle 60 -MaxProcessorUsage 99 -PollingCycle 15"
          }
          wait
        '';
        wantedBy = ["graphical-session.target"];
      };
      security.wrappers.sunshine.capabilities = mkOrder 900 "cap_sys_nice";
      services = {
        xserver.enable = true;
        sunshine = {
          enable = true;
          capSysAdmin = true;
          package = pkgs.shanetrs.sunshine;
        };
      };
    })
  ]);
}
