## Prompt Building

SGR () { for i in "$@"; do echo -ne "\e[$i"m; done; }

# nix-shell packages
[ -n "$NIX_SHELL_PACKAGES" ] && 
  PS1_NIX_SHELL="$(SGR 35)$NIX_SHELL_PACKAGES "

[ "$UID" -eq 0 ] && PS1_ROOT=31 || PS1_ROOT=32

PS1="$(SGR "$PS1_ROOT" 1)\$$(SGR 0) $PS1_NIX_SHELL$(SGR 90)[$(SGR 0)\h \w$(SGR 90)]$(SGR 0) ";
RPS1() { [ -n "$2" ] && printf "%*s\r" "$((COLUMNS + $1))" "${2@P}"; }

preexec() {
  [ -z "$RPS1_TIME_START" ] &&
    export RPS1_TIME_START="$(date +%s%3N)";
}
precmd() {
  RPS1_EXIT="$?"; SGR_COUNT=0
  history -a; history -w

  # Save and restore original right-handed prompt
  [ -z "$RPS1_ORIGINAL" ] &&
    RPS1_ORIGINAL="${RPS1:- }"
  RPS1="$RPS1_ORIGINAL"
  
  # Add execution timings for entries that last longer than RPS1_TIME_MIN
  [ -n "$RPS1_TIME_START" ] &&
    RPS1_TIME_ELAPSED="$(($(date +%s%3N) - RPS1_TIME_START))"
  if [ "$RPS1_TIME_ELAPSED" -gt "${RPS1_TIME_MIN:-800}" ]; then
    RPS1="⏳$(SGR 33 1)$(perl -e "printf('%.3f', $RPS1_TIME_ELAPSED / 1000)")s$(SGR 0)  $RPS1"
    ((SGR_COUNT += 14))
  fi
  unset RPS1_TIME_START RPS1_TIME_ELAPSED

  # Add an error code for entries with an exit code besides 0
  if [ "$RPS1_EXIT" -ne 0 ]; then
    RPS1="$(SGR 31 1)❌$RPS1_EXIT$(SGR 0)  $RPS1"
    ((SGR_COUNT += 14))
  fi

  RPS1 "$SGR_COUNT" "$(sed 's: *$::' <<< "$RPS1")"
}

trap 'preexec "$BASH_COMMAND"' DEBUG
PROMPT_COMMAND="precmd"

