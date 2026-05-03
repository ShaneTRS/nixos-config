{
  symlinkJoin,
  writeShellScriptBin,
  devcontainer,
  podman,
  podman-compose,
  ...
}:
symlinkJoin rec {
  name = "devcontainer";
  withPodman = devcontainer.override {
    docker = podman;
    docker-compose = podman-compose;
  };
  paths = [
    (writeShellScriptBin "docker" ''
      args=("$@")
      unwrapped() { exec ${podman}/bin/podman "''${args[@]}"; }
      get_matches() {
        local cf='devcontainer.config_file=(.*)' lf='devcontainer.local_folder=(.*)'
        for i in "''${args[@]}"; do
          if [[ $i =~ $cf ]]; then
            config_file="''${BASH_REMATCH[1]}"
          fi
          if [[ $i =~ $lf ]]; then
            local_folder="''${BASH_REMATCH[1]}"
          fi
        done
        [ -n "$1" ] || return
        [ -n "$config_file" ] || "$1"
        [ -n "$local_folder" ] || "$1"
      }

      if [ "$1" = ps ] && [ -z "$SKIP_DEVCONTAINER_WRAP" ]; then
        get_matches unwrapped
        SKIP_DEVCONTAINER_WRAP=1 ${withPodman}/bin/devcontainer up \
          "--config=$config_file" "--workspace-folder=$local_folder" &> /dev/null
      fi
      if [ "$1" = run ]; then
        get_matches unwrapped
        args=("$1" "--rm" "''${args[@]:2}")
      fi
      unwrapped
    '')
    withPodman
  ];
}
