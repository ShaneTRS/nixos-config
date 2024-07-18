{ pkgs, ... }:
with pkgs;
writeShellApplication {
  name = "addr-sort";
  runtimeInputs = [ coreutils inetutils ];
  text = ''
    set +o errexit
    (read -ra arr <<< "$@"
    for i in "''${arr[@]}"; do
    	if ping "$i" -c1 -W1 &>/dev/null; then
    		echo "$i"
    	fi &
    done
    sleep 0.25) | head -n1
  '';
}
