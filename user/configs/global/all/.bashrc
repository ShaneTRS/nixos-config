## Prompt Building

PS_SGR() { printf '\[\e[%s%sm\]' "$1" "$([ -n "$2" ] && printf ';%s' "${@:2}")"; }
PS_LENGTH() { local str="$(perl -pe 's|\\\[.*?\\\]||g' <<< "$*")"; wc -L <<< "${str@P}"; }
PS_PRINT() { echo -ne "${*@P}"; }

RPS1() { [ -n "$1" ] && printf "\e[%sG%s\r" "$((COLUMNS - $(PS_LENGTH "$*") + 1))" "${*@P}"; }

PS1_MULTILINE() {
  [ $((COLUMNS - $(PS_LENGTH "${PS1//\$(PS1_MULTILINE)}"))) -lt ${PS1_SHORTEN:-60} ] &&
    PS_PRINT "\n$PS1_ROOT$(PS_SGR 0) "
}
PS1_NIX_SHELL() {
  [ -n "$IN_NIX_SHELL" ] || return
  local IFS=: pkgs
  for i in $PATH; do
    [[ $i =~ /nix/store ]] ||
      if [ -n "$pkgs" ]; then break; else continue; fi
    i=${i:44:-4} i=${i%-[[:digit:]]*}
    [[ $pkgs =~ $i ]] || pkgs+=($i)
  done
  [ -n "$pkgs" ] && echo "$(PS_SGR 0 35)${pkgs[@]}$(PS_SGR 0) "
}

[ "$UID" -eq 0 ] && PS1_ROOT="$(PS_SGR 31 1)#" || PS1_ROOT="$(PS_SGR 32 1)\$"
PS1="$PS1_ROOT $(PS1_NIX_SHELL)$(PS_SGR 90)[$(PS_SGR 0)\h \w$(PS_SGR 90)]$(PS_SGR 0) \$(PS1_MULTILINE)"

preexec() { RPS1_TIME_START=${RPS1_TIME_START:-$(date +%s%3N)}; }
precmd() {
  RPS1_ERR=$? RPS1_ORIGINAL="${RPS1_ORIGINAL:-${RPS1:- }}"
  RPS1="$RPS1_ORIGINAL"
  
  [ -n "$RPS1_TIME_START" ] && RPS1_TIME_ELAPSED=$(($(date +%s%3N) - RPS1_TIME_START))
  [ "$RPS1_TIME_ELAPSED" -gt "${RPS1_TIME_MIN:-800}" ] &&
    RPS1="⏳$(PS_SGR 33 1)$(perl -e "printf('%.3f', $RPS1_TIME_ELAPSED / 1000)")s$(PS_SGR 0)  $RPS1"
  unset RPS1_TIME_START RPS1_TIME_ELAPSED
  
  [ $RPS1_ERR -ne 0 ] && RPS1="$(PS_SGR 31 1)❌$RPS1_ERR$(PS_SGR 0)  $RPS1"
  RPS1 "${RPS1%"${RPS1##*[! ]}"} "
}

## Bash Configuration

trap 'preexec "$BASH_COMMAND"' DEBUG
PROMPT_COMMAND="precmd"