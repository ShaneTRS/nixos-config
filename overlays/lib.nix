{
  self ? null,
  pkgs ? null,
  tree ? null,
  machine ? {},
  secrets ?
    if machine ? serial
    then self.nixosConfigurations.${machine.serial}.config.sops.secrets
    else {},
  nixpkgs ? self.inputs.nixpkgs,
  home-manager ? self.inputs.home-manager,
  ...
} @ args: final: prev: let
  inherit (builtins) attrNames filter foldl' isAttrs listToAttrs mapAttrs;
  inherit (builtins) elemAt fromJSON match readDir readFile;

  inherit (builtins) attrValues isFunction pathExists toJSON trace;

  inherit (nixpkgs.lib) collect findFirst filterAttrs nixosSystem;
  inherit (home-manager.lib) homeManagerConfiguration;

  tundra = rec {
    collectModules = modules: name: map (x: args: (x args).${name} or {}) modules;

    mkTree = dir: let
      deepReadDir = dir:
        mapAttrs (name: type:
          if type == "directory"
          then deepReadDir (dir + "/${name}")
          else dir + "/${name}")
        (readDir dir);
      filterNames = attrs: filter (x: match "_.*" x == null) (attrNames attrs);
      convertFiles = tree:
        listToAttrs (map (name: let
          file = tree.${name};
          regex = match "(.+)(\\.nix|\\.json|\\.toml)" name;
          ext = elemAt regex 1;
        in
          if regex != null
          then {
            name = elemAt regex 0;
            value =
              if ext == ".nix"
              then import file
              else if ext == ".json"
              then fromJSON (readFile file) // {__path = file;}
              else fromTOML (readFile file) // {__path = file;};
          }
          else {
            inherit name;
            value =
              if isAttrs file
              then convertFiles file
              else file;
          }) (filterNames tree));
    in
      convertFiles (deepReadDir dir);

    resolveList = list: map (x: x.content or x) (filter (x: x.condition or true) list);

    transformAttrs = rules: attrs: mapAttrs (k: v: foldl' (acc: this: this k acc) v rules) attrs;

    getOverlays = args: (map (x: x args) (filter isFunction (attrValues tree.overlays))); # tree

    # self, nixpkgs, machine, secrets
    configs = file:
      with machine;
        if secrets ? ${file}
        then secrets.${file}.path
        else
          findFirst pathExists (trace "no config was found for ${file}!" null) [
            "${self}/user/configs/${user}/${profile}/${file}"
            "${self}/user/configs/${user}/all/${file}"
            "${self}/user/configs/global/${profile}/${file}"
            "${self}/user/configs/global/all/${file}"
          ];

    # self, tree
    nixosConfigurations = set: let
      # todo: get rid of reliance on default.nix
      systems = filterAttrs (k: v: v != null) (
        mapAttrs
        (k: v: let
          machine =
            (v.default or v (args
              // {
                inherit machine;
                options = null;
                config = null;
                homeConfig = null;
                nixosConfig = null;
              })).machine or null;
        in
          if machine != null
          then
            {
              serial = k; # todo: remove this
              profile = k; # todo: remove this
              hostname = k;
              user = "user";
              source = "/home/${machine.user}/.config/nixos";
            }
            // machine
          else null)
        (filterAttrs (k: v: isFunction (v.default or v)) set)
      );

      tundraSystem = name: machine: let
        systemArgs =
          systemHelper machine
          // {
            nixosConfig = system.config;
            homeConfig = system.config.home-manager.users.${machine.user};
          };

        getModules = collectModules (collect isFunction tree.systems.${name});
        configModules = getModules "config";

        system = nixosSystem {
          inherit (systemArgs) lib;
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

    # self, tree
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

        getModules = collectModules (collect isFunction tree.systems.${machine.profile});

        home = homeManagerConfiguration {
          extraSpecialArgs = systemArgs;
          pkgs = systemArgs.pkgs;
          modules = with self.inputs;
            [
              self.homeModules.default
              sops.homeModules.default
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
          inherit (this.pkgs) lib;
          pkgs = pkgs.appendOverlays (getOverlays this);
        };
    in
      this;

    # pkgs
    toYAML = attrs: "${pkgs.runCommand "toYAML" {
        buildInputs = [pkgs.yj];
        attrs = toJSON attrs;
        passAsFile = ["attrs"];
      } ''
        mkdir -p $out
        yj -jy < "$attrsPath" > $out/attrs.yaml
      ''}/attrs.yaml";
  };
in {
  lib =
    if prev ? lib
    then prev.lib.extend (final: prev: home-manager.lib or {} // {inherit tundra;})
    else {inherit tundra;};
}
