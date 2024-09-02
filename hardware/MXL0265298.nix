# HP t530 Thin Client
{
  boot.kernelModules = [ "kvm-amd" ];
  fileSystems."/" = {
    device = "/dev/disk/by-label/Nix";
    fsType = "ext4";
    neededForBoot = true;
  };
  hardware.cpu.amd.updateMicrocode = true;
}
