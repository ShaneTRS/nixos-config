## Prompt Building

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

## Zsh Bindings & Preferences

zle -N history-search
zstyle ':completion:*' menu select
autoload -U select-word-style
select-word-style bash

typeset -g -A key