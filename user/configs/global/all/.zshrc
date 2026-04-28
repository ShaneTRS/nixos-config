## Prompt Building

setopt prompt_subst

PS_LENGTH() { print -P "$*" | sed 's:\x1B\[[0-9;]*[a-zA-Z]::g' | wc -L; }
PS_PRINT() { echo -ne "${*@P}"; }

PS1_MULTILINE() {
  [ $((COLUMNS - $(PS_LENGTH "${PS1//\$\(PS1_MULTILINE\)}"))) -lt ${PS1_SHORTEN:-60} ] &&
    echo "\n$PS1_ROOT%f "
}
PS1_NIX_SHELL() {
	[ -n "$IN_NIX_SHELL" ] || return
	local pkgs
  for i in "${(s/:/)PATH}"; do
    [[ $i =~ /nix/store ]] ||
      if [ -n "$pkgs" ]; then break; else continue; fi
    i=${i:44:-4} i=${i%-[[:digit:]]*}
    [[ $pkgs =~ $i ]] || pkgs+=($i)
  done
  [ -n "$pkgs" ] && echo "%F{5}${pkgs[@]}"
}

PS1_ROOT='%B%(!:%F{1}#:%F{2}$)%b'
PS1="$PS1_ROOT$(PS1_NIX_SHELL) %F{8}[%f%m %~%F{8}]%f \$(PS1_MULTILINE)";

preexec() { RPS1_TIME_START=$(date +%s%3N); }
precmd() {
  RPS1_ERR=$? RPS1_ORIGINAL="${RPS1_ORIGINAL:-${RPS1:- }}"
  RPS1="$RPS1_ORIGINAL"

  [ -n "$RPS1_TIME_START" ] && RPS1_TIME_ELAPSED=$(($(date +%s%3N) - RPS1_TIME_START))
  [ "$RPS1_TIME_ELAPSED" -gt "${RPS1_TIME_MIN:-800}" ] &&
    RPS1="⏳%B%F{3}$(printf '%.3f' "$((RPS1_TIME_ELAPSED / 1000.0))")s%b%f  $RPS1"
  unset RPS1_TIME_START RPS1_TIME_ELAPSED

  [ $RPS1_ERR -ne 0 ] && RPS1="%B%F{1}❌$RPS1_ERR%b%f  $RPS1"
  RPS1="${(*)RPS1/% #}"
}

## Zsh Bindings & Preferences

zle -N history-search
zstyle ':completion:*' menu select
autoload -U select-word-style
select-word-style bash

typeset -g -A key