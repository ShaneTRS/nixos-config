{pkgs, ...}: {
  services.earlyoom.enable = false;
  zramSwap.enable = false;

  tundra = {
    xdg.config = {
      # "git/config".enable = false;
      # "fastfetch/config.jsonc".enable = false;
    };
    home = {
      # ".ssh/config".enable = false;
      # ".ssh/authorized_keys".enable = false;
      # ".ssh/known_hosts".enable = false;
      "Desktop/example.a".text = "hello!";
      "Desktop/example.b".text = "hello!";
      "Desktop/example.c".text = "hello!";
    };
    filesystem = {
      # "/tmp/example" = {
      #   source = "bad";
      #   text = "hello";
      # };
      # "/home/shane:symlinkFarm global/all".enable = false;
      # "/home/shane:symlinkFarm global/id".enable = false;
      # "/home/shane:symlinkFarm user/all".enable = false;
      # "/home/shane:symlinkFarm user/id".enable = false;
      # "/tmp/bad" = {};
    };
    secret = {
      # "all/tundra".enable = false;
      # "all/zerotier".enable = false;
      # "all/.git-credentials".enable = false;
      # "all/.ssh/authorized_keys".enable = false;
      # "all/.ssh/known_hosts".enable = false;
      # "all/.vnc/passwd".enable = false;
      # "all/passwd".enable = false;
      # "persephone/jellyfin/jfa-go/password".enable = false;
      # "persephone/jellyfin/jfa-go/public_server".enable = false;
      # "persephone/noip/domains".enable = false;
      # "persephone/noip/pass".enable = false;
      # "persephone/noip/user".enable = false;
    };
  };

  shanetrs = {
    enable = true;
    browser.firefox.enable = true;
    desktop = {
      enable = true;
      gnome.enable = true;
    };
    programs.zed-editor = {
      enable = true;
      features = ["nix"];
    };
    shell.zsh.enable = true;
  };

  tundra.packages = with pkgs; [shanetrs.backups];
}
