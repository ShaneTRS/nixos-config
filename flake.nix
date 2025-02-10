{
  description = "My system configuration";

  inputs = {
    pkgs-stable.url = "nixpkgs/nixos-24.11";
    pkgs-unstable.url = "nixpkgs/nixos-unstable";
    pkgs-pinned.url = "nixpkgs/d0797a04b81caeae77bcff10a9dde78bc17f5661";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "pkgs-unstable";
    };
    sops = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "pkgs-unstable";
    };
  };

  outputs = { self, ... }@inputs:
    let
      config.allowUnfree = true;
      system = "x86_64-linux";

      machine = let
        inherit (builtins) fromTOML readFile;
        this = fromTOML (readFile ./machine.toml);
      in this // { profile = this.profile or this.hostname; };

      pkgs = functions.importRepo inputs.pkgs-unstable;
      pkgs-self = self.outputs.nixosConfigurations.default.pkgs;

      functions = let
        inherit (pkgs.lib) findFirst;
        inherit (builtins) filter map pathExists;
      in rec {
        secrets = self.outputs.nixosConfigurations.default.config.sops.secrets;
        configs = file:
          if secrets ? ${file} then
            secrets.${file}.path
          else
            findFirst (i: pathExists i) null [
              "${flake}/user/configs/${machine.user}/${machine.profile}/${file}"
              "${flake}/user/configs/${machine.user}/all/${file}"
              "${flake}/user/configs/global/${machine.profile}/${file}"
              "${flake}/user/configs/global/all/${file}"
            ];
        flake = self;
        importRepo = repo: import repo { inherit config system; };
        nixFolder = nix: let folder = "${./.}/${nix}"; in if pathExists folder then folder else folder + ".nix";
        resolveList = list: map (i: i.content or i) (filter (i: i.condition or true) list);
      };

      shellDeps = with pkgs-self; [
        coreutils
        gawk
        gnused
        git
        lix
        local.nix-shebang
        nixd
        nixos-rebuild
        nix-output-monitor
        sops
        sudo
        ugrep
      ];
    in {
      devShells.${system} = with pkgs; rec {
        default = repl;
        repl = mkShellNoCC { shellHook = ''exec nix repl --expr "builtins.getFlake \"${self}?submodules=1\""''; };
        sops = mkShellNoCC {
          buildInputs = [ ssh-to-age ] ++ shellDeps;
          shellHook = ''
            export SOPS_AGE_KEY="$(ssh-to-age -i "$HOME/.ssh/id_ed25519" -private-key 2>/dev/null)"
            [ -z "$SOPS_AGE_KEY" ] &&
              echo 'warning: ssh key was not found; keys will need to be provided'
            export NIX_SHELL_PACKAGES="sops"
            PREF_SHELL="$SHELL"; which zsh &>/dev/null && PREF_SHELL=zsh
            exec "$PREF_SHELL"
          '';
        };
      };
      formatter.${system} = pkgs.nixfmt-classic;

      legacyPackages.${system} = pkgs-self;
      packages.${system}.default = with pkgs;
        buildEnv {
          name = "flake-shell";
          paths = [ bash ] ++ shellDeps;
        };

      nixosConfigurations.default = let
        inherit (builtins) attrNames listToAttrs readDir replaceStrings;
        inherit (functions) nixFolder importRepo;
        inherit (inputs.pkgs-unstable.lib) mkAliasOptionModule nixosSystem;
        inherit (machine) user serial profile;
        inherit (pkgs) callPackage;
      in nixosSystem {
        modules = [
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
                      value = callPackage "${./packages}/${file}" {
                        pkgs = pkgs-self;
                        inherit functions machine self;
                      };
                    }) (attrNames (readDir ./packages)));
                  })
                ];
            };
            nix = {
              package = pkgs.lix;
              registry.pkgs.flake = self;
              settings = {
                auto-optimise-store = true;
                experimental-features = [ "nix-command" "flakes" "pipe-operator" ];
                nix-path = "nixpkgs=/etc/nix/inputs/pkgs";
                substituters = [ "file:///var/cache/nix" ];
                trusted-users = [ user ];
                use-xdg-base-directories = true;
              };
            };
          }
          { services.pipewire.package = pkgs-self.pinned.pipewire; }

          inputs.home-manager.nixosModules.home-manager
          inputs.sops.nixosModules.sops

          (mkAliasOptionModule [ "user" ] [ "home-manager" "users" user ])

          (nixFolder "profiles/${profile}")
          (if serial == "" then { } else nixFolder "hardware/${serial}")
          ./modules
        ];
        specialArgs = { inherit functions machine; };
      };
    };
}
