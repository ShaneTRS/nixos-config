{ pkgs, ... }: {
  shanetrs = {
    enable = true;
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
  };

  user.home.packages = with pkgs; [ krita vlc ];
}
