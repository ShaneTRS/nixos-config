let
  inherit (builtins) attrNames filter foldl' isAttrs listToAttrs mapAttrs;
  inherit (builtins) fromJSON match readDir readFile replaceStrings;
in {
  collectModules = modules: name: map (x: args: (x args).${name} or {}) modules;

  mkTree = dir: let
    createTree = dir:
      mapAttrs (name: type:
        if type == "directory"
        then createTree (dir + "/${name}")
        else dir + "/${name}")
      (readDir dir);

    filteredNames = attrs: filter (x: match "_.*" x == null) (attrNames attrs);

    convertTree = tree:
      listToAttrs (map (x: {
        name = replaceStrings [".nix" ".json" ".toml"] ["" "" ""] x;
        value = let
          file = tree.${x};
          ext = match ".+\\.(nix|json|toml)" x;
        in
          if ext == ["nix"]
          then import file
          else if ext == ["json"]
          then fromJSON (readFile file) // {__path = file;}
          else if ext == ["toml"]
          then fromTOML (readFile file) // {__path = file;}
          else if isAttrs file
          then convertTree file
          else file;
      }) (filteredNames tree));
  in
    convertTree (createTree dir);

  resolveList = list: map (x: x.content or x) (filter (x: x.condition or true) list);

  transformAttrs = rules: attrs: mapAttrs (k: v: foldl' (acc: this: this k acc) v rules) attrs;

  tundra = {
    self,
    lib,
    pkgs,
    tree,
    machine ? {},
    secrets ?
      if machine ? serial
      then self.nixosConfigurations.${machine.serial}.config.sops.secrets
      else {},
    ...
  } @ args: let
    inherit (builtins) attrValues isFunction pathExists toJSON trace;
    inherit (lib) collect collectModules nixosSystem homeManagerConfiguration;
  in rec {
    applyOverlays = pkgs: args:
      pkgs.appendOverlays (map (x: x args)
        (filter isFunction (attrValues tree.overlays)));

    configs = file:
      with machine;
        if secrets ? ${file}
        then secrets.${file}.path
        else
          lib.findFirst pathExists (trace "no config was found for ${file}!" null) [
            "${self}/user/configs/${user}/${profile}/${file}"
            "${self}/user/configs/${user}/all/${file}"
            "${self}/user/configs/global/${profile}/${file}"
            "${self}/user/configs/global/all/${file}"
          ];

    nixosConfigurations = systems: let
      tundraSystem = k: v: let
        machine =
          {
            profile = v.hostname;
            serial = k;
            source = "/home/${v.user}/.config/nixos/";
          }
          // v;
        systemArgs =
          systemHelper machine
          // {
            nixosConfig = system.config;
            homeConfig = system.config.home-manager.users.${machine.user};
          };

        getModules =
          collectModules (collect isFunction tree.profiles.${machine.profile}
            ++ collect isFunction tree.hardware.${machine.serial});
        configModules = getModules "config";

        system = nixosSystem {
          specialArgs = systemArgs;
          modules = with self.inputs;
            [
              self.outputs.nixosModules.default
              home-manager.nixosModules.default
              sops.nixosModules.default
              nixpkgs.nixosModules.readOnlyPkgs
              {
                environment.etc."nix/inputs/pkgs".source = nixpkgs;
                nixpkgs.pkgs = systemArgs.pkgs;
                nix = {
                  registry.pkgs.to = {
                    type = "git";
                    url = "file:" + machine.source;
                  };
                  settings = {
                    experimental-features = ["nix-command" "flakes"];
                    nix-path = "nixpkgs=/etc/nix/inputs/pkgs";
                  };
                };
                home-manager = {
                  extraSpecialArgs = systemArgs;
                  users.${machine.user}.imports =
                    [self.homeModules.default]
                    ++ (collect isFunction tree.user.homes.${machine.user} or {})
                    ++ getModules "home"
                    ++ configModules;
                };
              }
            ]
            ++ getModules "nixos"
            ++ configModules;
        };
      in
        system;
    in
      mapAttrs tundraSystem systems;

    homeConfigurations = homes: let
      tundraHome = k: v: let
        machine =
          {
            user = k;
            hostname = v.profile;
            source = "/home/${k}/.config/nixos/";
          }
          // v;
        systemArgs = systemHelper machine // {homeConfig = home.config;};

        getModules = collectModules (collect isFunction tree.profiles.${machine.profile});

        home = homeManagerConfiguration {
          extraSpecialArgs = systemArgs;
          pkgs = systemArgs.pkgs;
          modules =
            [
              self.homeModules.default
              {
                imports = collect isFunction tree.user.homes.${machine.user} or {};
                home = {
                  username = machine.user;
                  homeDirectory =
                    if machine ? home
                    then lib.mkForce machine.home
                    else "/home/${machine.user}";
                };
              }
            ]
            ++ getModules "home"
            ++ getModules "config";
        };
      in
        home;
    in
      mapAttrs tundraHome homes;

    systemHelper = machine: let
      this =
        args
        // {
          inherit machine;
          lib = lib // {tundra = lib.tundra this;};
          pkgs = applyOverlays pkgs this;
        };
    in
      this;

    toYAML = attrs: "${pkgs.runCommand "toYAML" {
        buildInputs = [pkgs.yj];
        attrs = toJSON attrs;
        passAsFile = ["attrs"];
      } ''
        mkdir -p $out
        yj -jy < "$attrsPath" > $out/attrs.yaml
      ''}/attrs.yaml";
  };
}
