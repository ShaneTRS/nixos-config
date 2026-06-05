{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  inherit (pkgs) writeShellScript;
in {
  systemd.user.services.pipewire-pulse.serviceConfig.ExecStart = mkIf config.programs.noisetorch.enable [
    ""
    (writeShellScript "pipewire-pulse" ''
      export LADSPA_PATH="$LADSPA_PATH:/tmp"
      exec ${config.services.pipewire.package}/bin/pipewire-pulse "$@"
    '')
  ];
}
