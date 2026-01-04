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
    inherit (base.lib) collect mkAliasOptionModule nixosSystem;
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
  in {
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
          if [ -z "$SOPS_AGE_KEY" ]; then
          	export SOPS_AGE_KEY="$(ssh-to-age -i "$HOME/.ssh/id_ed25519" -private-key 2>/dev/null)"
            [ -z "$SOPS_AGE_KEY" ] &&
            	echo warning: ssh key was not found\; keys will need to be provided
          fi
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
        program = pkgs.lib.getExe (tree.rebuild {inherit pkgs;});
      };
    };

    nixosConfigurations = let
      tundraSystem = machine: let
        overlays = overlayArgs systemArgs;
        systemArgs =
          specialArgs
          // {
            inherit machine;
            fn = systemFn;
            pkgs = pkgs.appendOverlays overlays;
          };
        systemFn = fn // (tree.functions.tundra systemArgs);
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
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
              };
              nixpkgs.pkgs = systemArgs.pkgs;
              nix = {
                registry.pkgs.flake = self;
                settings = {
                  auto-optimise-store = true;
                  experimental-features = ["nix-command" "flakes"];
                  nix-path = "nixpkgs=/etc/nix/inputs/pkgs";
                  trusted-users = [machine.user];
                  substituters = ["https://nix-community.cachix.org"];
                  trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
                  use-xdg-base-directories = true;
                };
              };
            }

            (importItem tree.profiles.${machine.profile})
            (importItem tree.hardware.${machine.serial})
          ];
        };
    in
      mapAttrs (serial: machine:
        tundraSystem ({
            profile = machine.hostname;
            inherit serial;
            source = "/home/${machine.user}/.config/nixos/";
          }
          // machine))
      {
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
          hostname = "lachesis";
          user = "mo";
        };
        "0" = {
          hostname = "vm";
          profile = "bolillo";
          user = "vm";
        };
      };

    nixosModules.default.imports = collect isFunction tree.modules;
  };
}
