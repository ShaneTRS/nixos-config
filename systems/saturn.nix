{pkgs, ...}: {
  shanetrs = {
    enable = true;
    browser = {
      firefox.enable = true;
      chromium.enable = true;
    };
    desktop = {
      enable = true;
      plasma.enable = true;
    };
    gaming = {
      # epic.enable = true;
      minecraft.enable = true;
      steam.enable = true;
    };
    remote = {
      enable = true;
      role = "host";
    };
    programs.discord.enable = true;
  };
  tundra.packages = with pkgs; [krita vlc];
}
