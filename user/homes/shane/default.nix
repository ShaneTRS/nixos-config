{
  machine,
  nixosConfig ? {},
  ...
}: {
  xdg.cacheFile."hm-status".text = "hello ${machine.user}! ${
    if nixosConfig ? system
    then "we are a ${nixosConfig.system.nixos.distroId} module!!"
    else "we are not a system module!!"
  }";
}
