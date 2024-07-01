{ pkgs, ... }: {

  environment.systemPackages = with pkgs; [ vlc libreoffice-still ];
  services = {
    flatpak.enable = true;
    printing.enable = true;
  };

  shanetrs = {
    browser.chromium.enable = true;
    desktop = {
      enable = true;
      session = "plasma";
    };
    programs.vscode.enable = true;
    shell.doas.enable = true;
    tundra.enable = true;
  };

  user.home.packages = with pkgs; [ flatpak gnome.gnome-software ];
}
