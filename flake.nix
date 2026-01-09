{
  description = "My 2nd generation system configuration";

  inputs = {
    self.submodules = true;
    pkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    pkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    pkgs-pinned.url = "github:nixos/nixpkgs/3e2499d5539c16d0d173ba53552a4ff8547f4539";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "pkgs-unstable";
    };
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "pkgs-unstable";
    };
    sops = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "pkgs-unstable";
    };
  };

  outputs = {self, ...} @ inputs: let
    inherit (builtins) attrValues filter isFunction mapAttrs;
    inherit (base.lib) collect getExe mkAliasOptionModule nixosSystem;
    inherit (fn) importItem fileTree;

    base = inputs.pkgs-unstable;
    fn = (import ./functions.nix).pure;
    tree = fileTree self;

    system = "x86_64-linux";
    pkgs = import base {
      inherit system;
      config = {
        allowUnfree = true;
        permittedInsecurePackages = [];
        inherit system;
      };
    };

    overlayArgs = args: map (x: x args) (filter isFunction (attrValues tree.overlays));
    specialArgs = {
      inherit self fn tree;
      pkgs = self.legacyPackages.${system};
    };

    systemHelper = machine: let
      this =
        specialArgs
        // {
          inherit machine;
          fn = fn // (tree.functions.tundra this);
          pkgs = pkgs.appendOverlays (overlayArgs this);
        };
    in
      this;
  in {
    nixosModules.default.imports = collect isFunction tree.modules;
    devShells.${system} = with pkgs; rec {
      default = repl;
      repl = mkShellNoCC {
        shellHook = ''
          exec nix repl --expr "let
            self = builtins.getFlake \"\${self}\";
            nixosConfiguration = self.nixosConfigurations.\"''${TUNDRA_SERIAL:-230925799001945}\";
            eval = nixosConfiguration.config.system.build.toplevel;
          in
          	{ inherit nixosConfiguration eval; }
           	// self.outputs
            // nixosConfiguration
            // nixosConfiguration._module.specialArgs
            // nixosConfiguration.config.home-manager.users"
        '';
      };
      sops = mkShellNoCC {
        buildInputs = [pkgs.sops pkgs.ssh-to-age];
        shellHook = ''
          export SOPS_AGE_KEY="''${SOPS_AGE_KEY:-$(ssh-to-age -i "$HOME/.ssh/id_ed25519" -private-key 2>/dev/null)}"
          [ -z "$SOPS_AGE_KEY" ] &&
          	echo warning: ssh key was not found\; keys will need to be provided
          for i in zsh fish bash sh; do
          	type -P $i >/dev/null && exec $i
          done
        '';
      };
    };
    formatter.${system} = pkgs.alejandra;
    legacyPackages.${system} = pkgs.appendOverlays (overlayArgs specialArgs);
    apps.${system} = rec {
      default = rebuild;
      rebuild = {
        type = "app";
        program = getExe (tree.rebuild {inherit pkgs;});
      };
    };

    nixosConfigurations = let
      tundraSystem = key: value: let
        machine =
          {
            profile = value.hostname;
            serial = key;
            source = "/home/${value.user}/.config/nixos/";
          }
          // value;
        systemArgs = systemHelper machine;
      in
        nixosSystem {
          specialArgs = systemArgs;
          modules = [
            inputs.home-manager.nixosModules.default
            inputs.sops.nixosModules.default
            self.outputs.nixosModules.default

            (mkAliasOptionModule ["user"] ["home-manager" "users" machine.user])
            base.nixosModules.readOnlyPkgs

            {
              environment.etc."nix/inputs/pkgs".source = base;
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
            }

            (importItem tree.profiles.${machine.profile})
            (importItem tree.hardware.${machine.serial})
          ];
        };
    in
      mapAttrs tundraSystem {
        "230925799001945" = {
          hostname = "persephone";
          user = "shane";
        };
        "H1XH7F3CNCMC0015F0243" = {
          hostname = "lachesis";
          user = "shane";
        };
        "MXL0265298" = {
          hostname = "dionysus";
          user = "shane";
        };
        "MOELITEBOOK" = {
          hostname = "mo-elitebook";
          user = "mo";
        };
        "0" = {
          hostname = "vm";
          profile = "bolillo";
          user = "vm";
        };
      };

    homeConfigurations = let
      tundraHome = key: value: let
        machine =
          {
            user = key;
            hostname = value.profile;
            source = "/home/${key}/.config/nixos/";
          }
          // value;
        systemArgs = systemHelper machine;
        shim = nixosSystem {
          specialArgs = systemArgs;
          modules = [
            inputs.home-manager.nixosModules.default
            inputs.sops.nixosModules.default
            self.outputs.nixosModules.default
            (mkAliasOptionModule ["user"] ["home-manager" "users" machine.user])
            base.nixosModules.readOnlyPkgs
            ({
              config,
              lib,
              ...
            }: {
              nixpkgs.pkgs = systemArgs.pkgs;
              user.home = {
                username = machine.user;
                homeDirectory =
                  if machine ? home
                  then lib.mkForce machine.home
                  else config.users.users.${machine.user}.home;
              };
            })
            (importItem tree.profiles.${machine.profile})
          ];
        };
      in
        inputs.home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = systemArgs;
          pkgs = systemArgs.pkgs;
          modules = shim.options.user.definitions;
        };
    in
      mapAttrs tundraHome {
        "shane".profile = "persephone";
        "mo".profile = "crumb";
      };
  };
}
