# Prompt Building

SGR () { for i in "$@"; do echo -ne "\e[$i"m; done; }

# nix-shell packages
[ -n "$NIX_SHELL_PACKAGES" ] && 
  PS1_NIX_SHELL="%F{5}$NIX_SHELL_PACKAGES "

PS1="%B%(!:%F{1}#:%F{2}$)%b $PS1_NIX_SHELL%F{8}[%f%m %~%F{8}]%f ";

preexec() { RPS1_TIME_START="$(date +%s%3N)"; }
precmd() {
  RPS1_EXIT="$?"

  # Save and restore original right-handed prompt
  [ -z "$RPS1_ORIGINAL" ] &&
    RPS1_ORIGINAL="${RPS1:- }"
  RPS1="$RPS1_ORIGINAL"
  
  # Add execution timings for entries that last longer than RPS1_TIME_MIN
  [ -n "$RPS1_TIME_START" ] &&
    RPS1_TIME_ELAPSED="$(($(date +%s%3N) - RPS1_TIME_START))"
  [ "$RPS1_TIME_ELAPSED" -gt "${RPS1_TIME_MIN:-800}" ] &&
    RPS1="⏳%B%F{3}$(perl -e "printf('%.3f', $RPS1_TIME_ELAPSED / 1000)")s%b%f  $RPS1"
  unset RPS1_TIME_START RPS1_TIME_ELAPSED

  # Add an error code for entries with an exit code besides 0
  [ "$RPS1_EXIT" -ne 0 ] &&
    RPS1="%B%F{1}❌$RPS1_EXIT%b%f  $RPS1"

  # Trim trailing whitespace
  RPS1="$(sed 's: *$::' <<< "$RPS1")"
}

# Custom Functions

nix-run() {
  NIXPKGS_ALLOW_UNFREE=1 nix shell --impure "pkgs#$1" \
    --command sh -c "which ${1#*.} &>/dev/null && exec ${1#*.} ${*:2}; exec ${*:2}"
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

if which nix-index &>/dev/null; then
  nix-find() { nix-locate --no-group --top-level -r "$@"; }
  command_not_found_handler() {(
    CMD="$1"; IFS=$'\n'
    if [ "$NIX_MISSING" = "never" ]; then
      echo "$(SGR 1 34)❭❭ $(SGR 0 1)$CMD$(SGR 0) not found! You can use $(SGR 1)nix-find -wtx /$CMD$(SGR 0) to find it" >&2
      exit 127
    fi
    PACKAGES=($(nix-locate --minimal --no-group --type x --type s --top-level --whole-name --at-root "/bin/$CMD"))
    case "${#PACKAGES}" in
      0) echo "$(SGR 1 34)❭❭ $(SGR 0 1)$CMD$(SGR 0) not found! Are you sure you've typed the command correctly?" >&2 ;;
      1) [ "$NIX_MISSING" = "auto" ] &&
          exec nix-shell "${PACKAGES[1]}" --command "$@";
        echo -n "$(SGR 1 34)❭❭ $(SGR 0 1)$CMD$(SGR 0) not found! Would you like to bring $(SGR 1)${PACKAGES[1]%.*}$(SGR 0) into scope? " >&2; read
        exec nix-shell "${PACKAGES[1]}" --command "$@" ;;
      *) [ "$NIX_MISSING" = "always" ] &&
          exec nix-shell "${PACKAGES[1]}" --command "$@";
        echo "$(SGR 1 34)❭❭ $(SGR 0 1)$CMD$(SGR 0) not found! Would you like to bring one of the following packages into scope?" >&2
        PS3=""; select PKG in ${PACKAGES[@]%.*}; do exec nix-shell "$PKG" --command "$@"; done ;;
    esac
    exit 127
  )}
fi

# Zsh Bindings & Preferences

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