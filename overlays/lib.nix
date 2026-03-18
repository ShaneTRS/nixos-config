{
  self ? null,
  pkgs ? null,
  tree ? null,
  machine ? {},
  secrets ?
    if machine ? id
    then
      (
        if machine ? home
        then {} # self.homeConfigurations.${machine.user}.config.sops.secrets # infinite recursion
        else self.nixosConfigurations.${machine.id}.config.sops.secrets
      )
    else {},
  nixpkgs ? self.inputs.nixpkgs,
  home-manager ? self.inputs.home-manager,
  ...
} @ args: final: prev: let
  inherit (builtins) attrNames filter foldl' isAttrs listToAttrs mapAttrs;
  inherit (builtins) elemAt fromJSON match readDir readFile;

  inherit (builtins) attrValues isFunction pathExists toJSON trace;

  inherit (nixpkgs.lib) collect findFirst filterAttrs mkOverride nixosSystem;
  inherit (home-manager.lib) homeManagerConfiguration;

  tundra = rec {
    collectModules = modules: name: map (x: args: (x args).${name} or {}) modules;

    mkStrongDefault = mkOverride 900;

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
    getConfig = file:
      with machine;
        if secrets ? ${file}
        then secrets.${file}.path
        else
          findFirst pathExists (trace "no config was found for ${file}!" null) [
            (self + "/user/configs/${user}/${id}/${file}")
            (self + "/user/configs/${user}/all/${file}")
            (self + "/user/configs/global/${id}/${file}")
            (self + "/user/configs/global/all/${file}")
          ];

    getMachines = set:
      filterAttrs (k: v: v != null) (mapAttrs (k: v: let
        machines = filter (x: x != null) (map (x: let
          this =
            (x ({
                machine = this;
                options = null;
                config = null;
                homeConfig = null;
                nixosConfig = null;
              }
              // args)).machine or null;
        in
          this) (collect isFunction v));
      in
        if machines != []
        then foldl' (acc: this: acc // this) {} machines
        else null)
      set);

    # self, tree
    tundraSystem = name: value: let
      machine =
        rec {
          id = name;
          hostname = name;
          user = "user";
          source = "/home/${machine.user or user}/.config/nixos";
        }
        // value;

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

    # self, tree
    tundraHome = name: value: let
      machine =
        {
          user = name;
          hostname = value.id;
          source = "/home/${name}/.config/nixos/";
          home = "/home/${machine.user}";
        }
        // value;
      systemArgs = systemHelper machine // {homeConfig = home.config;};

      getModules = collectModules (collect isFunction tree.systems.${machine.id});

      home = homeManagerConfiguration {
        extraSpecialArgs = systemArgs;
        pkgs = systemArgs.pkgs;
        modules =
          [
            self.homeModules.default
            # sops.homeModules.default # cannot access secrets due to infinite recursion
            {
              imports = collect isFunction tree.user.homes.${machine.user} or {};
              home = {
                username = machine.user;
                homeDirectory = mkOverride 900 machine.home;
              };
            }
          ]
          ++ getModules "home"
          ++ getModules "config";
      };
    in
      home;

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
