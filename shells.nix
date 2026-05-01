{
  self,
  pkgs,
  ...
}: let
  inherit (builtins) fromJSON readFile;
  lock = fromJSON (readFile (self + "/flake.lock"));
in rec {
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
  secrets = sops.overrideAttrs (old: {
    shellHook =
      ''
        cd "$TMPDIR"
        git clone '${lock.nodes.secrets.original.url}' "$TMPDIR"
        trap "rm -rf '$TMPDIR'" EXIT
      ''
      + old.shellHook;
  });
  sops = pkgs.mkShellNoCC {
    buildInputs = [pkgs.sops pkgs.ssh-to-age];
    shellHook = ''
      export SOPS_AGE_KEY="''${SOPS_AGE_KEY:-$(ssh-to-age -i "$HOME/.ssh/id_ed25519" -private-key 2>/dev/null)}"
      [ -n "$SOPS_AGE_KEY" ] || echo warning: ssh key was not found\; keys will need to be provided >&2
      "$(awk -F: /$USER/'{print $NF}' /etc/passwd)" "$@"; exit $?
    '';
  };
}
