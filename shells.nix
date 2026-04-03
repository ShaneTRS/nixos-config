{pkgs, ...}: rec {
  default = repl;
  repl = pkgs.mkShellNoCC {
    shellHook = ''
      exec nix repl --expr "let
        self = builtins.getFlake \"git+file:$PWD\";
        nixosConfiguration = self.nixosConfigurations.\"''${TUNDRA_ID:-persephone}\";
       	eval = nixosConfiguration.config.system.build.toplevel;
        specialArgs = nixosConfiguration._module.specialArgs;
      in
      	{ inherit self eval specialArgs; }
       	// self.outputs
        // nixosConfiguration
        // specialArgs"
    '';
  };
  sops = pkgs.mkShellNoCC {
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
}
