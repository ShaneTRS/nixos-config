{ pkgs, ... }: {

  environment.systemPackages = with pkgs; [ git vlc ];
  services.flatpak.enable = true;
  system.autoUpgrade.enable = true;

  shanetrs = {
    browser = {
      firefox.enable = true;
      chromium.enable = true;
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
      default = pkgs.zsh;
      zsh.enable = true;
      doas.enable = true;
    };
  };

  user = { home = { packages = with pkgs; [ flatpak gnome.gnome-software krita ]; }; };
}
