PS1=%F{8}[%f%n\ %~%F{8}]%f\ ;RPS1=%T

[ -n "$NIX_SHELL_PACKAGES" ] &&
PS1="%F{1}$NIX_SHELL_PACKAGES $PS1"

alias nixos-rebuild=use_doas
use_doas() { echo "error: you're trying to run this command as a normal user!" 1>&2; false; }
nix-run() {
  NIXPKGS_ALLOW_UNFREE=1 nix shell --impure "pkgs#$1" --command sh -c "which $1 &>/dev/null && exec $*; exec ${*:2}";
}
nix-shell() {(
  for i in "$@"; do
    if [ -n "$OPTION" ] || [[ "${i:0:1}" == "-" ]]; then
      ARGS+=" \"$i\""
      OPTION=1; continue
    fi
    NIX_SHELL_PACKAGES+=" $i";
    ARGS+=" \"pkgs#$i\""
  done
  eval "NIX_SHELL_PACKAGES=\"${NIX_SHELL_PACKAGES#* }\" NIXPKGS_ALLOW_UNFREE=1 nix shell --impure $ARGS"
)}
where() { readlink -f "$(which "$@")"; }

zle -N history-search
zstyle ':completion:*' menu select
autoload -U select-word-style
select-word-style bash

typeset -g -A key
key[Insert]='^[[2~'
key[Home]='^[[H'
key[PageUp]='^[[5~'
key[Delete]='^[[3~'
key[End]='^[[F'
key[PageDown]='^[[6~'
bindkey "$\{key[Insert]}" overwrite-mode
bindkey "$\{key[Home]}" beginning-of-line ";5H" beginning-of-line ";3H" beginning-of-line
bindkey "$\{key[PageUp]}" up-line-or-history
bindkey "$\{key[Delete]}" delete-char
bindkey "$\{key[End]}" end-of-line ";5F" end-of-line ";3F" end-of-line
bindkey "$\{key[PageDown]}" down-line-or-history
bindkey "5~" kill-word "3~" kill-word
bindkey ";3C" .accept-line ";5C" .accept-line
bindkey ";3C" forward-word ";5C" forward-word
bindkey ";3D" backward-word ";5D" backward-word
bindkey '^[s' history-incremental-search-backward