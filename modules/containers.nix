{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (builtins) elem;
  inherit (lib) getExe escapeShellArgs mkEnableOption mkIf mkMerge mkOption optionalString remove types;
  cfg = config.shanetrs.containers;
  opt = options.shanetrs.containers;
in {
  options.shanetrs.containers = {
    enable = mkEnableOption "Setup containers for system services";
    directory = mkOption {
      type = types.str;
      default = "${config.tundra.paths.home}/Containers";
    };
    preStart = mkOption {
      type = types.lines;
      default = "";
    };
    autoStart = mkOption {
      type = types.listOf types.str;
      default = ["running"];
    };
    after = mkOption {
      type = types.listOf types.str;
      default = ["network-online.target"];
    };
    uinput = mkOption {
      type = types.bool;
      default = false;
    };
  };
  config = mkIf cfg.enable (mkMerge [
    {
      shanetrs.containers = {
        autoStart = opt.autoStart.default;
        after = opt.after.default;
      };
      systemd.services.shanetrs-containers = let
        getRunning = ''
          ${getExe pkgs.podman} container ps -qf restart-policy=unless-stopped |
            paste -sd' ' > .shanetrs/running;
        '';
      in {
        script = ''
          export PATH="${pkgs.slirp4netns}/bin:$PATH"
          touch .shanetrs/running
          containers=(${optionalString (elem "running" cfg.autoStart) "$(cat .shanetrs/running)"} \
            ${escapeShellArgs (remove "running" cfg.autoStart)})
          [ -z "$containers" ] || ${getExe pkgs.podman} start "''${containers[@]}"
          while true; do
            sleep 30m
            ${getRunning}
          done
        '';
        preStop = ''
          ${getRunning}
          ${getExe pkgs.podman} stop -ai
        '';
        serviceConfig = {
          PAMName = "login";
          User = config.tundra.user;
          WorkingDirectory = cfg.directory;
        };
        restartIfChanged = false;
        inherit (cfg) after preStart;
        wants = cfg.after;
        requires = ["podman.socket"];
        wantedBy = ["default.target"];
      };
      tundra.filesystem = {
        "${cfg.directory}" = {
          type = "directory";
          inherit (config.tundra) user;
        };
        "${cfg.directory}/.shanetrs" = {
          type = "directory";
          inherit (config.tundra) user;
        };
        "${cfg.directory}/.shanetrs/aio" = {
          inherit (config.tundra) user;
          source = getExe pkgs.shanetrs.server-aio;
          mode = "555";
        };
      };
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
        extraPackages = [pkgs.slirp4netns];
      };
    }

    (mkIf cfg.uinput {
      security.wrappers.vuinputd = {
        owner = "root";
        group = "root";
        capabilities = "cap_sys_admin,cap_mknod,cap_dac_override,cap_fowner+eip";
        source = getExe pkgs.shanetrs.vuinputd;
      };
      services.udev = {
        enable = true;
        packages = [pkgs.shanetrs.vuinputd];
        extraHwdb = ''
          evdev:input:b0003v1209p5020e????-*
           ID_VUINPUT=1

          input:b0003v1209p5020e????-*
           ID_VUINPUT=1
        '';
      };
      systemd.services.vuinputd = {
        script = "${config.security.wrapperDir}/vuinputd --major 120 --minor 414795";
        after = ["systemd-udevd.service"];
        requires = ["systemd-udevd.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig.DeviceAllow = "char-* rwm";
      };
    })
  ]);
}
