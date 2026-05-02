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
  enabled = cfg.development.enable || cfg.services.enable;
in {
  options.shanetrs.containers = {
    development = {
      enable = mkEnableOption "Setup containers for software development";
      # todo: devcontainers
    };
    services = {
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
  };
  config = mkMerge [
    (mkIf enabled {
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
        extraPackages = [pkgs.slirp4netns];
      };
    })

    (mkIf cfg.services.enable {
      shanetrs.containers.services = {
        autoStart = opt.services.autoStart.default;
        after = opt.services.after.default;
      };
      systemd.services.shanetrs-containers = let
        getRunning = ''
          ${getExe pkgs.podman} container ps -qf restart-policy=unless-stopped |
            paste -sd' ' > .shanetrs/running;
        '';
      in {
        inherit (cfg.services) preStart;
        script = ''
          export PATH="${pkgs.slirp4netns}/bin:$PATH"
          touch .shanetrs/running
          containers=(${optionalString (elem "running" cfg.services.autoStart) "$(cat .shanetrs/running)"} \
            ${escapeShellArgs (remove "running" cfg.services.autoStart)})
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
          WorkingDirectory = cfg.services.directory;
        };
        restartIfChanged = false;
        after = cfg.services.after;
        wants = cfg.services.after;
        requires = ["podman.socket"];
        wantedBy = ["default.target"];
      };
      tundra.filesystem = {
        "${cfg.services.directory}" = {
          type = "directory";
          inherit (config.tundra) user;
        };
        "${cfg.services.directory}/.shanetrs" = {
          type = "directory";
          inherit (config.tundra) user;
        };
        "${cfg.services.directory}/.shanetrs/aio" = {
          inherit (config.tundra) user;
          source = getExe pkgs.shanetrs.server-aio;
          mode = "555";
        };
      };
    })

    (mkIf (enabled && cfg.services.uinput) {
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
  ];
}
