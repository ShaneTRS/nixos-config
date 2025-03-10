## Prompt Building
setopt prompt_subst
PS1_SHORTEN() { [ $((COLUMNS - ${#PS1})) -lt 5 ]; }
PS1_NIX_SHELL() {(
	[ -z "$IN_NIX_SHELL" ] && return
  DIRS=(${(s/:/)PATH}) PKGS=()
  for i in "${DIRS[@]}"; do
    [[ $i =~ /nix/store ]] ||
      if [ -n "$PKGS" ]; then break; else continue; fi
    PKG=${${i:44:-4}%-[[:digit:]]*}
    [[ $PKGS =~ $PKG ]] || PKGS+=$PKG
  done 2> /dev/null
  [ -n "$PKGS" ] && echo "%F{5}${(j: :)PKGS} "
)}

PS1_ROOT='%B%(!:%F{1}#:%F{2}$)%b'
PS1_MULTILINE() { PS1_SHORTEN && echo "\n$PS1_ROOT%f "; }

PS1="$PS1_ROOT $(PS1_NIX_SHELL)%F{8}[%f%m %~%F{8}]%f \$(PS1_MULTILINE)";

preexec() { RPS1_TIME_START="$(date +%s%3N)"; }
precmd() {
  RPS1_EXIT="$?"

  # Save and restore original right-handed prompt
  [ -z "$RPS1_ORIGINAL" ] && RPS1_ORIGINAL="${RPS1:- }"
  RPS1="$RPS1_ORIGINAL"

  # Add execution timings for entries that last longer than RPS1_TIME_MIN
  [ -n "$RPS1_TIME_START" ] &&
    RPS1_TIME_ELAPSED="$(($(date +%s%3N) - RPS1_TIME_START))"
  [ "$RPS1_TIME_ELAPSED" -gt "${RPS1_TIME_MIN:-800}" ] &&
     RPS1="⏳%B%F{3}$(printf '%.3f' $((RPS1_TIME_ELAPSED / 1000.0)))s%b%f  $RPS1"
  unset RPS1_TIME_START RPS1_TIME_ELAPSED

  # Add an error code for entries with an exit code besides 0
  [ "$RPS1_EXIT" -ne 0 ] &&
    RPS1="%B%F{1}❌$RPS1_EXIT%b%f  $RPS1"

  # Trim trailing whitespace
  RPS1="${(*)RPS1/% #}"
}

## Zsh Bindings & Preferences

zle -N history-search
zstyle ':completion:*' menu select
autoload -U select-word-style
select-word-style bash

typeset -g -A key