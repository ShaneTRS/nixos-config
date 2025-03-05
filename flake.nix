{
  description = "My 2nd generation system configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    pkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    pkgs-pinned.url = "github:nixos/nixpkgs/d0797a04b81caeae77bcff10a9dde78bc17f5661";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "pkgs-unstable";
    };
    sops = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "pkgs-unstable";
    };
  };

  outputs = {self, ...} @ inputs: let
    inherit (builtins) attrValues filter isFunction map pathExists replaceStrings;
    inherit (base.lib) findFirst mkAliasOptionModule nixosSystem warn;
    inherit (functions) importItem;

    tree = functions.fileTree self;

    base = inputs.pkgs-unstable;
    pkgs = functions.importRepo base;
    pkgs-self = self.outputs.nixosConfigurations.default.pkgs;

    config.allowUnfree = true;
    system = "x86_64-linux";

    machine = let
      x = tree.machine;
    in
      x
      // {
        source = replaceStrings ["\${user}"] [x.user] x.source;
        profile = x.profile or x.hostname;
      };

    functions = with machine; rec {
      secrets = self.outputs.nixosConfigurations.default.config.sops.secrets;
      configs = file:
        if secrets ? ${file}
        then secrets.${file}.path
        else
          findFirst (i: pathExists i) (warn "no config was found for ${file}!" null) [
            "${self}/user/configs/${user}/${profile}/${file}"
            "${self}/user/configs/${user}/all/${file}"
            "${self}/user/configs/global/${profile}/${file}"
            "${self}/user/configs/global/all/${file}"
          ];
      fileTree = dir: import ./file-tree.nix dir;
      importItem = nix:
        if isFunction nix
        then nix
        else nix.default;
      importRepo = repo: import repo {inherit config system;};
      resolveList = list: map (i: i.content or i) (filter (i: i.condition or true) list);
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

    specialArgs = {inherit self functions machine tree;};
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
          export SOPS_AGE_KEY="$(ssh-to-age -i "$HOME/.ssh/id_ed25519" -private-key 2>/dev/null)"
          [ -z "$SOPS_AGE_KEY" ] &&
            echo 'warning: ssh key was not found; keys will need to be provided'
          export NIX_SHELL_PACKAGES="sops"
          PREF_SHELL="$SHELL"; which zsh &>/dev/null && PREF_SHELL=zsh
          exec "$PREF_SHELL"
        '';
      };
    };
    formatter.${system} = pkgs.alejandra;
    legacyPackages.${system} = pkgs-self;
    packages.${system}.default = with pkgs;
      buildEnv {
        name = "flake-shell";
        paths = [bash] ++ shellDeps;
      };
    apps.${system}.default = {
      type = "app";
      program = base.lib.getExe (import ./rebuild.nix {inherit machine pkgs shellDeps;});
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
              use-xdg-base-directories = true;
            };
          };
        }
        {services.pipewire.package = pkgs-self.pinned.pipewire;}

        (importItem tree.profiles.${machine.profile})
        (
          if tree.hardware ? "${machine.serial}"
          then importItem tree.hardware.${machine.serial}
          else {}
        )
      ];
    };

    nixosModules.default.imports = base.lib.collect isFunction tree.modules;

    # homeConfigurations.default = {};
  };
}
