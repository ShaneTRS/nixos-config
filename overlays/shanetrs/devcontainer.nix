{
  devcontainer,
  podman,
  podman-compose,
  ...
}:
devcontainer.override {
  docker = podman;
  docker-compose = podman-compose;
}
