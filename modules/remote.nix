{ config, lib, pkgs, functions, machine, ... }:
let
  cfg = config.shanetrs.remote;
  inherit (functions) configs;
  inherit (lib) concatStringsSep getExe mkEnableOption mkIf mkMerge mkOption optionalString types;
  inherit (pkgs) makeDesktopItem writeShellApplication writeShellScriptBin;
in {
  options.shanetrs.remote = {
    enable = mkEnableOption "Low-latency access to a remote machine";
    role = mkOption {
      type = types.enum [ "host" "client" ];
      example = "host";
    };
    package = mkOption {
      type = types.package;
      default = pkgs.local.tigervnc;
    };
    addresses = {
      host = mkOption {
        type = types.listOf types.str;
        default = [ "10.42.0.1" "192.168.1.11" ];
      };
      client = mkOption {
        type = types.listOf types.str;
        default = [ "10.42.0.2" "192.168.1.12" ];
      };
    };
    usb = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      devices = mkOption {
        type = types.str;
        example = "/sys/bus/pci/devices/0000:00:14.0/usb2/";
      };
      ports = mkOption {
        type = if cfg.role == "client" then types.listOf types.str else null;
        example = [ "2-2" "2-4" ];
      };
    };
    audio = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      sinkName = mkIf (cfg.role == "host") (mkOption {
        type = types.str;
        default = "Laptop Speakers";
      });
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      security.doas.extraRules = mkIf cfg.usb.enable [{
        users = [ machine.user ];
        keepEnv = true;
        noPass = true;
        cmd = "usbip";
      }];
      environment.systemPackages = [ cfg.package (mkIf cfg.usb.enable config.boot.kernelPackages.usbip) ];
      systemd.services.usbipd = mkIf cfg.usb.enable {
        script = "${config.boot.kernelPackages.usbip}/bin/usbipd";
        wantedBy = [ "default.target" ];
      };
      boot.kernelModules = mkIf cfg.usb.enable [ "usbip-core" "usbip-host" "vhci-hcd" ];
    }

    (mkIf (cfg.role == "host") {
      services.xserver.enable = true;
      hardware.pulseaudio.extraConfig = ''
        load-module module-null-sink sink_name=roc-output sink_properties=device.description='${cfg.audio.sinkName}'
      '';

      user.systemd.user.services = {
        x0vncserver = {
          Unit.Description = "Low-latency VNC display server";
          Service = {
            Environment = "DISPLAY=:0";
            ExecStart = let attempt = configs ".vnc/passwd";
            in "${getExe pkgs.local.not-nice} x0vncserver Geometry=2732x1536 ${
              optionalString (attempt != null) ''-rfbauth "${attempt}"''
            } -FrameRate 60 -PollingCycle 60 -CompareFB 2 -MaxProcessorUsage 99 -PollingCycle 15";
            Restart = "on-failure";
            StartLimitBurst = 32;
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
        roc-send = {
          Unit.Description = "Low-latency VNC display server";
          Service = {
            Environment = ''CLIENT="${concatStringsSep " " cfg.addresses.client}"'';
            ExecStart = "${getExe pkgs.local.not-nice} ${
                getExe (writeShellApplication {
                  name = "roc-send.service";
                  runtimeInputs = with pkgs; [ local.addr-sort gawk local.not-nice pulseaudio roc-toolkit ];
                  text = ''
                    set +o errexit
                    if [ -z "''${THAT:-}" ]; then
                      # shellcheck disable=SC2048 disable=SC2086
                      THAT=$(addr-sort ''${CLIENT[*]})
                    fi
                    ssh "$THAT" -f 'systemctl --user restart roc-recv.service'
                    sink="$(pactl list sources short | awk '/output/ {print $1; exit}')"
                    # shellcheck disable=SC2128
                    roc-send -s"rtp+rs8m://$THAT:48820" -r"rs8m://$THAT:48821" \
                      --rate=24500 --resampler-profile=low --resampler-backend speex \
                      --io-latency=20ms --frame-length 4ms -i"pulse://$sink"
                  '';
                })
              }";
            Restart = "on-failure";
            StartLimitBurst = 32;
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      };
    })

    (mkIf (cfg.role == "client") {
      systemd.services = mkIf cfg.usb.enable {
        usbip-resume = {
          after = [ "suspend.target" ];
          serviceConfig = {
            Type = "oneshot";
            User = machine.user;
          };
          script = "${getExe (writeShellApplication {
            name = "usbip-resume";
            runtimeInputs = with pkgs; [ procps ];
            text = ''
              pkill usbip.service -USR1
              pkill -f loop-vncviewer.child
            '';
          })}";
          wantedBy = [ "suspend.target" ];
        };
      };
      user = {
        home.packages = [
          (makeDesktopItem {
            name = "loop-vncviewer";
            desktopName = "loop-vncviewer";
            exec = let attempt = configs ".vnc/passwd";
            in getExe (writeShellScriptBin "loop-vncviewer" ''
              while true; do
                addr="$(${getExe pkgs.local.addr-sort} ${concatStringsSep " " config.shanetrs.remote.addresses.host})"
                [ -n "$addr" ] &&
                  (exec -a "loop-vncviewer.child" "vncviewer" -RemoteResize=1 -PointerEventInterval=0 -AlertOnFatalError=0 ${
                    optionalString (attempt != null) ''-passwd="${attempt}"''
                  } /home/${machine.user}/.vnc/loop.tigervnc "$addr")
                sleep .6
              done
            '');
            terminal = false;
            type = "Application";
            icon = "krdc";
          })
        ];
        systemd.user.services = {
          roc-recv = mkIf cfg.audio.enable {
            Unit.Description = "Low-latency remote audio receiver";
            Service = {
              ExecStart = "${getExe (writeShellApplication {
                name = "roc-recv.service";
                runtimeInputs = with pkgs; [ local.not-nice roc-toolkit ];
                text = ''
                  not-nice roc-recv -srtp+rs8m://0.0.0.0:48820 -rrs8m://0.0.0.0:48821 \
                    --rate=24500 --resampler-profile=low --resampler-backend speex --frame-len=4ms \
                    --io-latency=1ms --latency-profile=responsive -o"pulse://default"
                '';
              })}";
              Restart = "on-failure";
              StartLimitBurst = 32;
            };
            Install.WantedBy = [ "graphical-session.target" ];
          };
          usbip = mkIf cfg.usb.enable {
            Unit.Description = "Low-latency USB devices over ethernet";
            Service = {
              Environment = [
                "TARGET='${concatStringsSep " " cfg.addresses.host}'"
                "PORTS='${concatStringsSep " " cfg.usb.ports}'"
                "DEVICES=${cfg.usb.devices}"
              ];
              ExecStart = "${getExe (writeShellApplication {
                name = "usbip.service";
                runtimeInputs = with pkgs; [
                  coreutils
                  gash-utils
                  local.addr-sort
                  libnotify
                  openssh
                  systemd
                  util-linux
                ];
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
                        # shellcheck disable=SC2048 disable=SC2086
                        THAT=$(addr-sort ''${TARGET[*]})
                        echo "TARGET: $THAT"
                        # shellcheck disable=SC1083
                        ssh "$THAT" doas usbip attach -r"\''${SSH_CLIENT%% *}" -b"$bus"
                        notify connect "$bus" "$THAT"
                        udevadm wait "$usb" --removed
                        notify disconnect "$bus" "$THAT"
                      done &
                      pids+=($!)
                    done
                    echo "''${pids[@]}"
                  }

                  detach_port () {
                    # shellcheck disable=SC2048 disable=SC2086
                    THAT=$(addr-sort ''${TARGET[*]})
                    echo "TARGET: $THAT"
                    read -ra arr <<< "$@"
                    for i in "''${arr[@]}"; do
                      ssh "$THAT" doas usbip detach -p"$i"
                    done
                  }

                  handle_trap () { exit 2; }
                  trap handle_trap USR1

                  while true; do
                    # shellcheck disable=SC2048 disable=SC2086
                    THAT=$(addr-sort ''${TARGET[*]})
                    [ -z "$THAT" ] || break
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
            Install.WantedBy = [ "graphical-session.target" ];
          };
        };
      };
    })
  ]);
}
