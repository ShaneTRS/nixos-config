{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (builtins) readFile;
  inherit (lib) getExe mkIf optionalString;
  inherit (lib.tundra) getConfig' mkIfConfig;

  jfa-go-conf = getConfig' [] "jfa-go.ini";
in {
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
  networking.extraHosts = ''
    192.168.1.11 shanetrs.ddns.net
  '';

  tundra.secret = {
    "jfa-go.ini" = mkIf (jfa-go-conf != null) {
      text = readFile jfa-go-conf;
    };
    "ddclient.conf".text = let
      cfg = config.services.ddclient;
      boolYN = x:
        if x
        then "YES"
        else "NO";
    in ''
      cache=/var/lib/ddclient/ddclient.cache
      foreground=YES
      usev4=${cfg.usev4}
      protocol=${cfg.protocol}
      server=${cfg.server}
      ssl=${boolYN cfg.ssl}
      wildcard=YES
      quiet=${boolYN cfg.quiet}
      verbose=${boolYN cfg.verbose}

      login=%%noip.user
      password=%%noip.pass
      $%%noip.domains
    '';
  };
  services = {
    ddclient = {
      usev4 = "webv4, webv4=ifconfig.so/";
      interval = "3h";
      protocol = "noip";
      server = "dynupdate.no-ip.com";
      configFile = config.tundra.secret."ddclient.conf".target;
    };
    nix-serve = {
      enable = true;
      openFirewall = true;
      port = 5698;
      secretKeyFile = "/var/cache-priv-key.pem";
    };
  };

  environment.etc."keynavrc" = mkIfConfig "keynavrc" (x: {
    source = x;
  });
  systemd.user.services = {
    shadowplay = {
      script = getExe pkgs.shanetrs.shadowplay;
      wantedBy = ["graphical-session.target"];
    };
    keynav = {
      script = getExe pkgs.keynav;
      wantedBy = ["graphical-session.target"];
    };
    jfa-go = {
      script = ''
        sleep 15
        ${getExe pkgs.shanetrs.jfa-go} ${optionalString (jfa-go-conf != null) "-c '${config.tundra.secret."jfa-go.ini".target}'"}
      '';
      wantedBy = ["graphical-session.target"];
    };
  };
}
