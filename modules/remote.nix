{
  config,
  lib,
  pkgs,
  fn,
  machine,
  ...
}: let
  inherit (fn) configs;
  inherit (lib) concatStringsSep getExe mkEnableOption mkPackageOption mkIf mkMerge mkOption optionalString types;
  inherit (pkgs) makeDesktopItem writeShellApplication writeShellScriptBin;
  inherit (builtins) attrNames listToAttrs toJSON;
  cfg = config.shanetrs.remote;
in {
  options.shanetrs.remote = {
    enable = mkEnableOption "Low-latency access to a remote machine";
    role = mkOption {
      type = types.enum ["host" "client"];
      example = "host";
    };
    package = mkPackageOption pkgs.shanetrs "tigervnc" {};
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
          users = [machine.user];
          keepEnv = true;
          noPass = true;
          cmd = "usbip";
        }
      ];
      environment.systemPackages = [cfg.package (mkIf cfg.usb.enable config.boot.kernelPackages.usbip)];
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
      systemd.services = mkIf cfg.usb.enable {
        usbip-resume = {
          after = ["suspend.target"];
          serviceConfig = {
            Type = "oneshot";
            User = machine.user;
          };
          script = "${getExe (writeShellApplication {
            name = "usbip-resume";
            runtimeInputs = with pkgs; [procps];
            text = ''
              pkill usbip.service -USR1
              pkill -f loop-vncviewer.child
              pkill -P "$(pgrep ml-launcher)" -KILL
            '';
          })}";
          wantedBy = ["suspend.target"];
        };
      };
      user = {
        home.packages = [
          pkgs.shanetrs.ml-launcher
          (makeDesktopItem {
            name = "loop-vncviewer";
            desktopName = "loop-vncviewer";
            exec = let
              attempt = configs ".vnc/passwd";
            in
              getExe (writeShellScriptBin "loop-vncviewer" ''
                TARGET="''${TARGET:-shanetrs.remote.host}"
                while true; do
                  ping "$TARGET" -c1 &&
                    (exec -a "loop-vncviewer.child" "vncviewer" -RemoteResize=1 -PointerEventInterval=0 -AlertOnFatalError=0 \
                     		${optionalString (attempt != null) ''-passwd="${attempt}"''} <(sed "s:\$TARGET:$TARGET:g" /home/${machine.user}/.vnc/loop.tigervnc))
                  sleep .6
                done
              '');
            terminal = false;
            type = "Application";
            icon = "krdc";
          })
        ];
        systemd.user.services = {
          usbip = mkIf cfg.usb.enable {
            Unit.Description = "Low-latency USB devices over ethernet";
            Service = {
              Environment = [
                "TARGET=shanetrs.remote.host"
                "PORTS='${optionalString cfg.usb.enable concatStringsSep " " cfg.usb.ports}'"
                "DEVICES=${cfg.usb.devices}"
              ];
              ExecStart = "${getExe (writeShellApplication {
                name = "usbip.service";
                runtimeInputs = with pkgs; [coreutils gash-utils libnotify openssh systemd util-linux];
                text = ''
                  set +o errexit
                  if ! doas true; then
                    sleep 3
                    exit 1
                  fi

                  notify () {
                    [ "$1" == "disconnect" ] &&
                      str="Disconnected port $2 from host at $3" ||
                      str="Connected port $2 to host at $3";
                    notify-send -i network-"$1" -a usb-forwarding \
                      'USB Port Forwarding' "$str" -t 1000
                  }

                  forward_port () {
                    read -ra arr <<< "$@"
                    for i in "''${arr[@]}"; do
                      usb=$DEVICES''${i%-*}/''${i%.*}
                      [[ "$i" == *"."* ]] && usb+="/$i"
                      bus=''${usb//*\/}
                      while :; do
                        udevadm wait "$usb"
                        sleep 0.2s
                        doas usbip unbind -b"$bus" &>/dev/null
                        doas usbip bind -b"$bus"
                        sleep 0.2s
                        # shellcheck disable=SC1083
                        ssh "$TARGET" doas usbip attach -r"\''${SSH_CLIENT%% *}" -b"$bus"
                        notify connect "$bus" "$TARGET"
                        udevadm wait "$usb" --removed
                        notify disconnect "$bus" "$TARGET"
                      done &
                      pids+=($!)
                    done
                    echo "''${pids[@]}"
                  }

                  detach_port () {
                    read -ra arr <<< "$@"
                    for i in "''${arr[@]}"; do
                      ssh "$TARGET" doas usbip detach -p"$i"
                    done
                  }

                  handle_trap () { exit 2; }
                  trap handle_trap USR1

                  while true; do
                    ping "$TARGET" -c1 && break
                    sleep 1
                  done

                  detach_port 7 6 5 4 3 2 1 0
                  sleep 1
                  # shellcheck disable=SC2048 disable=SC2086
                  forward_port ''${PORTS[*]}
                  wait
                '';
              })}";
              Restart = "on-failure";
              StartLimitBurst = 32;
            };
            Install.WantedBy = ["graphical-session.target"];
          };
        };
        xdg.configFile = let
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
            })
            (attrNames input)));
      };
    })

    (mkIf (cfg.role == "host") {
      services.xserver.enable = true;
      user = {
        xdg.configFile = let
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
            })
            (attrNames input)));
        systemd.user.services = {
          x0vncserver = {
            Unit.Description = "Low-latency VNC display server";
            Service = {
              Environment = "DISPLAY=:0";
              ExecStart = let
                attempt = configs ".vnc/passwd";
              in "${getExe pkgs.shanetrs.not-nice} x0vncserver Geometry=2732x1536 ${
                optionalString (attempt != null) ''-rfbauth "${attempt}"''
              } -FrameRate 60 -PollingCycle 60 -CompareFB 2 -MaxProcessorUsage 99 -PollingCycle 15";
              Restart = "on-failure";
              StartLimitBurst = 32;
            };
            Install.WantedBy = ["graphical-session.target"];
          };
          sunshine = {
            Unit.Description = "Self-hosted game stream host for Moonlight";
            Service = {
              ExecStart = with pkgs; "${getExe shanetrs.not-nice} ${getExe shanetrs.sunshine}";
              Restart = "on-failure";
              StartLimitBurst = 32;
            };
            Install.WantedBy = ["graphical-session.target"];
          };
        };
      };
    })
  ]);
}
