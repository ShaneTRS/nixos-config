let
  inherit (builtins) attrNames attrValues filter foldl' isAttrs isFunction listToAttrs mapAttrs pathExists;
  inherit (builtins) fromJSON isString match readDir readFile replaceStrings toJSON trace;
in {
  collectModules = modules: name: map (x: args: (x args).${name} or {}) modules;

  mkTree = dir: let
    createTree = {
      dir,
      item ? {
        k = ".";
        v = "directory";
      },
    }:
      if item ? v && item.v == "directory"
      then let
        __path = "${dir}/${item.k}";
      in {
        dir = __path;
        item =
          mapAttrs (k: v:
            createTree {
              item = {inherit k v;};
              dir = __path;
            }) (readDir __path)
          // {inherit __path;};
      }
      else dir;

    filteredTreeNames = tree: filter (x: match "_.*" x == null) (attrNames tree);

    convertTree = tree:
      if isAttrs tree
      then
        listToAttrs (map (key: {
          name = replaceStrings [".nix" ".json" ".toml"] ["" "" ""] key;
          value = let
            __path = "${tree.${key}}/${key}";
            ext = match ".*\\.(nix|json|toml)" key;
          in
            if ext == ["nix"]
            then import __path
            else if ext == ["json"]
            then fromJSON (readFile __path) // {inherit __path;}
            else if ext == ["toml"]
            then fromTOML (readFile __path) // {inherit __path;}
            else if isString tree.${key} && match "__.*" key == null
            then __path
            else tree.${key};
        }) (filteredTreeNames tree))
      else tree;

    simplifyTree = tree:
      if tree ? item
      then mapAttrs (k: v: convertTree (simplifyTree v)) tree.item
      else tree;
  in
    convertTree (simplifyTree (createTree {inherit dir;}));

  resolveList = list: map (i: i.content or i) (filter (i: i.condition or true) list);

  transformAttrs = rules: attrs: mapAttrs (k: v: foldl' (acc: f: f k acc) v rules) attrs;

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
