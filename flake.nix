{
  description = "My system configuration";

  inputs = {
    pkgs-stable.url = "nixpkgs/nixos-24.05";
    pkgs-unstable.url = "nixpkgs/nixos-unstable";
    pkgs-pinned.url = "nixpkgs/79baff8812a0d68e24a836df0a364c678089e2c7"; # March 1st, 2024

    sops = {
      url = "github:Mic92/sops-nix";
      inputs = {
        nixpkgs-stable.follows = "pkgs-stable";
        nixpkgs.follows = "pkgs-stable";
      };
    };

    # This cannot be simplified because flake.nix is *not* a real nix file. Only `self.outputs` is.
    hm-stable = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "pkgs-stable";
    };
    hm-unstable = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "pkgs-unstable";
    };
    hm-pinned = {
      url = "github:nix-community/home-manager/652fda4ca6dafeb090943422c34ae9145787af37"; # March 1st, 2024
      inputs.nixpkgs.follows = "pkgs-pinned";
    };
  };

  outputs = { self, ... }@inputs:
    let
      inherit (builtins) fromTOML readFile pathExists;

      machine = let this = fromTOML (readFile ./machine.toml); in this // { profile = this.profile or this.hostname; };
      inherit (machine) base serial system;

      config.allowUnfree = true;
      pkgs = functions.importRepo inputs."pkgs-${base}";
      pkgs-self = self.outputs.nixosConfigurations.default.pkgs;

      functions = let inherit (pkgs.lib) findFirst;
      in rec {
        configs = file:
          if secrets ? ${file} then
            secrets.${file}.path
          else
            findFirst (f: pathExists f) null [
              "${flake}/user/configs/${machine.user}/${machine.profile}/${file}"
              "${flake}/user/configs/${machine.user}/all/${file}"
              "${flake}/user/configs/global/${machine.profile}/${file}"
              "${flake}/user/configs/global/all/${file}"
            ];
        flake = self;
        importRepo = repo: import repo { inherit system config; };
        nixFolder = nix: let folder = "${./.}/${nix}"; in if pathExists folder then folder else folder + ".nix";
        resolveList = l: builtins.map (i: i.content or i) (builtins.filter (i: i.condition or true) l);
        secrets = self.outputs.nixosConfigurations.default.config.sops.secrets;
      };
    in {
      devShells.${system} = with pkgs; rec {
        default = repl;
        repl = mkShellNoCC { shellHook = ''exec nix repl --expr "builtins.getFlake \"$PWD?submodules=1\""''; };
        sops = mkShellNoCC {
          buildInputs = [ ssh-to-age ];
          shellHook = ''
            export SOPS_AGE_KEY=$(ssh-to-age -i "$HOME/.ssh/id_ed25519" -private-key 2>/dev/null);
            [ -z "$SOPS_AGE_KEY" ] &&
              echo 'warning: ssh key was not found; keys will need to be provided'
            export NIX_SHELL_PACKAGES="sops";
            exec nix shell
          '';
        };
      };
      formatter.${system} = pkgs.nixfmt-classic;
      packages.${system}.default = with pkgs-self;
        buildEnv {
          name = "flake-shell";
          paths = [ bash coreutils gawk gnused git lix unstable.nixd nix-output-monitor sops sudo ugrep ];
        };
      legacyPackages.${system} = pkgs-self;
      nixosConfigurations.default = let inherit (inputs."pkgs-${base}") lib;
      in lib.nixosSystem {
        modules = let
          inherit (builtins) attrNames listToAttrs readDir replaceStrings;
          inherit (functions) nixFolder importRepo;
        in [
          {
            environment.etc."nix/inputs/pkgs".source = self;
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
            };
            nixpkgs = {
              inherit config;
              hostPlatform = system;
              overlays = with inputs;
                [
                  (final: prev: {
                    stable = importRepo pkgs-stable;
                    unstable = importRepo pkgs-unstable;
                    pinned = importRepo pkgs-pinned;
                    local = listToAttrs (map (file: {
                      name = replaceStrings [ ".nix" ] [ "" ] file;
                      value = pkgs.callPackage "${./packages}/${file}" { inherit functions machine pkgs; };
                    }) (attrNames (readDir ./packages)));
                  })
                ];
            };
            nix = {
              package = pkgs.lix;
              registry.pkgs.flake = self;
              settings = {
                auto-optimise-store = true;
                experimental-features = [ "nix-command" "flakes" ];
                nix-path = "nixpkgs=/etc/nix/inputs/pkgs";
                substituters = [ "file:///var/cache/nix" ];
                trusted-users = [ machine.user ];
                use-xdg-base-directories = true;
              };
            };
          }

          inputs."hm-${base}".nixosModules.home-manager
          inputs.sops.nixosModules.sops

          (lib.mkAliasOptionModule [ "user" ] [ "home-manager" "users" machine.user ])

          (nixFolder "profiles/${machine.profile}")
          (if serial == "" then { } else nixFolder "hardware/${serial}")
          ./modules
        ];
        specialArgs = { inherit functions machine; };
      };
    };
}
