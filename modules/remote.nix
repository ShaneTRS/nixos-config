{ config, lib, pkgs, functions, machine, ... }:
let
  cfg = config.shanetrs.remote;
  inherit (lib) concatStringsSep mkEnableOption mkIf mkMerge mkOption types;
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

      user = let
        roc-send-bin = pkgs.writeShellApplication {
          name = "roc-send.service";
          runtimeInputs = with pkgs; [ local.addr-sort local.not-nice pulseaudio roc-toolkit ];
          text = ''
            set +o errexit
            if [ -z "''${THAT:-}" ]; then
              # shellcheck disable=SC2048 disable=SC2086
              THAT=$(addr-sort ''${CLIENT[*]})
            fi
            ssh "$THAT" -f 'systemctl --user restart roc-recv.service'
            # shellcheck disable=SC2128
            roc-send -s"rtp+rs8m://$THAT:48820" -r"rs8m://$THAT:48821" \
              --rate=24500 --resampler-profile=low --resampler-backend speex \
              --io-latency=20ms --frame-length 4ms -i"pulse://$sink"
          '';
        };
      in {
        systemd.user.services = {
          x0vncserver = {
            Unit.Description = "Low-latency VNC display server";
            Service = {
              Environment = "DISPLAY=:0";
              ExecStart = let attempt = builtins.tryEval (functions.configs "vnc-passwd");
              in "${pkgs.local.not-nice}/bin/not-nice x0vncserver Geometry=2732x1536 ${
                if attempt.success then ''-rfbauth "${attempt.value}"'' else ""
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
              ExecStart = "${pkgs.local.not-nice}/bin/not-nice ${roc-send-bin}/bin/roc-send.service";
              Restart = "on-failure";
              StartLimitBurst = 32;
            };
            Install.WantedBy = [ "graphical-session.target" ];
          };
        };
      };
    })

    (mkIf (cfg.role == "client") {
      user = let
        roc-recv-bin = pkgs.writeShellApplication {
          name = "roc-recv.service";
          runtimeInputs = with pkgs; [ local.not-nice roc-toolkit ];
          text = ''
            not-nice roc-recv -srtp+rs8m://0.0.0.0:48820 -rrs8m://0.0.0.0:48821 \
              --rate=24500 --resampler-profile=low --resampler-backend speex \
              --io-latency=20ms --frame-length 4ms -o"pulse://default"
          '';
        };
        usbip-bin = pkgs.writeShellApplication {
          name = "usbip.service";
          runtimeInputs = with pkgs; [ coreutils doas local.addr-sort libnotify openssh systemd util-linux ];
          text = ''
            set +o errexit # disable exit on error

            notify () {
              notify-send -i network-"$1" -a usb-forwarding 'USB Port Forwarding' "''${1^}ed port $2 to remote computer" -t 1000
            }

            forward_port () {
              read -ra arr <<< "$@"
              for i in "''${arr[@]}"; do
                usb=/sys/bus/pci/devices/0000:00:14.0/usb2/''${i%.*}
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
                  # shellcheck disable=SC2016 disable=SC2288
                  ssh "$THAT" doas usbip attach -r'' + "'" + ''
                ''${SSH_CLIENT%% *}' -b"$bus"
                    notify connect "$bus"
                    udevadm wait "$usb" --removed
                    notify disconnect "$bus"
                  done&
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
        };
      in {
        home.packages = [
          (pkgs.makeDesktopItem {
            name = "loop-vncviewer";
            desktopName = "loop-vncviewer";
            exec = "${
                let attempt = builtins.tryEval (functions.configs "vnc-passwd");
                in pkgs.writeScriptBin "loop-vncviewer" ''
                  #!/usr/bin/env sh
                  while true; do
                    vncviewer -RemoteResize=1 -PointerEventInterval=0 -AlertOnFatalError=0 ${
                      if attempt.success then ''-passwd="${attempt.value}"'' else ""
                    } /home/${machine.user}/.vnc/loop.tigervnc \
                    "$(${pkgs.local.addr-sort}/bin/addr-sort ${
                      lib.concatStringsSep " " config.shanetrs.remote.addresses.host
                    })"
                    sleep .6
                  done
                ''
              }/bin/loop-vncviewer";
            terminal = false;
            type = "Application";
            icon = "krdc";
          })
        ];
        systemd.user.services = {
          roc-recv = mkIf cfg.audio.enable {
            Unit.Description = "Low-latency remote audio receiver";
            Service = {
              ExecStart = "${roc-recv-bin}/bin/roc-recv.service";
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
              ];
              ExecStart = "${usbip-bin}/bin/usbip.service";
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
