{ pkgs, ... }: {

  environment.systemPackages = with pkgs; [ git vlc ];
  services.flatpak.enable = true;
  system.autoUpgrade.enable = true;

  shanetrs = {
    browser = {
      enable = true;
      exec = "chromium";
    };
    desktop = {
      enable = true;
      session = "plasma";
    };
    gaming = {
      # epic.enable = true;
      minecraft.enable = true;
      steam.enable = true;
    };
    remote = {
      enable = true;
      package = pkgs.tigervnc;
      role = "host";
    };
    programs = {
      discord.enable = true;
      vscode.enable = true;
    };
    shell = {
      enable = true;
      exec = "zsh";
    };
  };

  user = { home = { packages = with pkgs; [ flatpak gnome.gnome-software krita ]; }; };
}
