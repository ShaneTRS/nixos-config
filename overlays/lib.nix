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
  inherit (builtins) elemAt fromJSON match readDir readFile sort;

  inherit (builtins) attrValues isFunction pathExists toJSON warn;

  inherit (nixpkgs.lib) collect findFirst filterAttrs mkOverride nixosSystem;
  inherit (home-manager.lib) homeManagerConfiguration;

  tundra = rec {
    deepReadDir = dir:
      mapAttrs (name: type:
        if type == "directory"
        then deepReadDir (dir + "/${name}")
        else dir + "/${name}")
      (readDir dir);

    # nixpkgs
    getCombinedModules = dir: class: let
      mapDirModules = mapModules (collect isFunction dir);
      sharedModules = mapDirModules (x: {
        options = x.options or {};
        config = x.config or {};
      });
      classModules = mapDirModules (x: x.${class} or {});
    in
      sharedModules ++ classModules;

    # self, nixpkgs, machine, secrets
    getConfig = file:
      if secrets ? ${file}
      then secrets.${file}.path
      else
        findFirst pathExists (warn "no config was found for ${file}!" null) (with machine; [
          (self + "/user/configs/${user}/${id}/${file}")
          (self + "/user/configs/${user}/all/${file}")
          (self + "/user/configs/global/${id}/${file}")
          (self + "/user/configs/global/all/${file}")
        ]);

    # nixpkgs
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

    getOverlays' = list: args: map (x: x args) (filter isFunction list);
    getOverlays = args: getOverlays' (attrValues tree.overlays) args; # tree

    mapModules' = modules: argsFn: outFn:
      map (x: args @ {
        extendModules,
        modules,
        pkgs,
        utils,
        ...
      }:
        outFn (x (argsFn args)))
      modules;
    mapModules = modules: outFn: mapModules' modules (x: x) outFn;

    mkStrongDefault = mkOverride 900;

    mkTree = dir: let
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
    sortPriorities = list: sort (a: b: (a.priority or 100) < (b.priority or 100)) list;

    transformAttrs = rules: attrs: mapAttrs (k: v: foldl' (acc: this: this k acc) v rules) attrs;

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
      combinedSystemModules = getCombinedModules tree.systems.${name};

      system = nixosSystem {
        specialArgs = removeAttrs systemArgs ["pkgs" "lib"];
        inherit (systemArgs) pkgs lib;
        modules =
          combinedSystemModules "nixos"
          ++ (with self.inputs; [
            self.outputs.nixosModules.default
            home-manager.nixosModules.default
            sops.nixosModules.default
            {
              environment.etc."nix/inputs/pkgs".source = nixpkgs;
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
                  combinedSystemModules "home"
                  ++ [self.homeModules.default]
                  ++ (collect isFunction tree.user.homes.${machine.user} or {});
              };
            }
          ]);
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

      home = homeManagerConfiguration {
        extraSpecialArgs = removeAttrs systemArgs ["pkgs" "lib"];
        inherit (systemArgs) pkgs lib;
        modules =
          getCombinedModules tree.systems.${machine.id} "home"
          ++ [
            self.homeModules.default
            # sops.homeModules.default # secrets cause inf. recursion
            {
              imports = collect isFunction tree.user.homes.${machine.user} or {};
              home = {
                username = machine.user;
                homeDirectory = mkOverride 900 machine.home;
              };
            }
          ];
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
