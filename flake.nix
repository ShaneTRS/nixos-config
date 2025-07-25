{
  description = "My 2nd generation system configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    pkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    pkgs-pinned.url = "github:nixos/nixpkgs/698214a32beb4f4c8e3942372c694f40848b360d";

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
    inherit (builtins) attrValues filter isFunction map replaceStrings;
    inherit (base.lib) collect getExe mkAliasOptionModule nixosSystem optionalAttrs;
    inherit (fn) importItem importRepo fileTree;

    base = inputs.pkgs-unstable;
    nixosConfiguration = self.outputs.nixosConfigurations.default;
    pkgs = importRepo base;

    config.allowUnfree = true;
    system = "x86_64-linux";

    pkgs-self = nixosConfiguration.pkgs;

    fn = import ./functions.nix {
      inherit self machine pkgs;
      inherit (nixosConfiguration.config.sops) secrets;
      pkgsConfig = {inherit config system;};
    };
    tree = fileTree self;

    machine = let
      x = tree.machine;
    in
      x
      // {
        source = replaceStrings ["\${user}"] [x.user] x.source;
        profile = x.profile or x.hostname;
      };

    shellDeps = with pkgs; [
      coreutils
      gawk
      git
      jq
      lix
      nixd
      nixos-rebuild
      nix-output-monitor
      ssh-to-age
      sops
    ];

    specialArgs = {inherit self fn machine tree;};
  in {
    devShells.${system} = with pkgs; rec {
      default = repl;
      repl = mkShellNoCC {
        shellHook = ''
          exec nix repl --expr "let
            self = builtins.getFlake \"${machine.source}\";
            nixosConfiguration = self.nixosConfigurations.default;
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
        buildInputs = shellDeps;
        shellHook = ''
          export NIX_SHELL_PACKAGES=impure
          if [ -z "$SOPS_AGE_KEY" ]; then
          	export SOPS_AGE_KEY="$(ssh-to-age -i "$HOME/.ssh/id_ed25519" -private-key 2>/dev/null)"
            [ -z "$SOPS_AGE_KEY" ] &&
            	echo warning: ssh key was not found\; keys will need to be provided
          fi
          type zsh &> /dev/null && exec zsh
        '';
      };
    };
    formatter.${system} = pkgs.alejandra;
    legacyPackages.${system} = pkgs-self;
    apps.${system}.default = {
      type = "app";
      program = getExe (import ./rebuild.nix {inherit machine pkgs shellDeps;});
    };

    nixosConfigurations.default = nixosSystem {
      inherit specialArgs;
      modules = [
        inputs.home-manager.nixosModules.default
        inputs.sops.nixosModules.default
        self.outputs.nixosModules.default

        (mkAliasOptionModule ["user"] ["home-manager" "users" machine.user])

        {
          environment.etc."nix/inputs/pkgs".source = inputs.pkgs-unstable;
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
          };
          nixpkgs = {
            inherit config;
            hostPlatform = system;
            overlays =
              map (x: x (specialArgs // {pkgs = pkgs-self;}))
              (filter isFunction (attrValues tree.overlays));
          };
          nix = {
            package = pkgs.lix;
            registry.pkgs.flake = self;
            settings = {
              auto-optimise-store = true;
              experimental-features = ["nix-command" "flakes" "pipe-operator"];
              nix-path = "nixpkgs=/etc/nix/inputs/pkgs";
              trusted-users = [machine.user];
              substituters = ["https://nix-community.cachix.org"];
              trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
              use-xdg-base-directories = true;
            };
          };
        }

        (importItem tree.profiles.${machine.profile})
        (optionalAttrs
          (tree.hardware ? "${machine.serial}")
          (importItem tree.hardware.${machine.serial}))
      ];
    };
    homeConfigurations.default = inputs.home-manager.lib.homeManagerConfiguration {
      extraSpecialArgs = specialArgs;
      modules =
        nixosConfiguration.options.user.definitions
        ++ [
          {
            home = {
              username = machine.user;
              homeDirectory = nixosConfiguration.config.users.users.${machine.user}.home;
            };
          }
        ];
      pkgs = pkgs-self;
    };

    nixosModules.default.imports = collect isFunction tree.modules;
  };
}
