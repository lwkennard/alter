# ~/.config/shell/greeting.sh — sourced from ~/.bashrc, after devtools.sh.
# Prints the system-info banner when a new terminal opens, and gives you
# `fetch` to print it again on demand.
#
#   fetch                 print it now (any fastfetch flags are passed through)
#   ALTER_NO_GREETING=1   never print it automatically
#   ALTER_GREETED         the tty this banner was last printed on
#
# The picture is a plain text file you own: ~/.config/fastfetch/logo.txt, which
# is a symlink to config/fastfetch/logo.txt in this repo. Edit it and the next
# terminal shows the change; there is no build step. The layout beside it comes
# from config/fastfetch/config.jsonc.

# Where the ASCII art lives. The ~/.config path is the symlink; the repo path
# is the fallback for a checkout whose dotfiles stage has not run yet.
_alter_logo_file() {
  local f
  for f in "$HOME/.config/fastfetch/logo.txt" "${ALTER_ROOT:-$HOME/alter}/config/fastfetch/logo.txt"; do
    [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }
  done
  return 1
}

# Fallback without fastfetch, used when it is not installed (non-Debian
# machine, or ALTER_SKIP_FASTFETCH=1). Same idea, standard shell tools, no colours
# beyond plain ANSI. Prints the logo above the facts rather than beside them:
# aligning two columns needs the art's display width, which escape sequences
# and double-width glyphs make unknowable in pure shell.
_alter_fetch_plain() {
  local f v host="${HOSTNAME:-?}" key=$'\033[35m' dim=$'\033[2m' off=$'\033[0m'
  [ -t 1 ] || { key=; dim=; off=; }

  # $1..$9 are fastfetch colour placeholders. Strip them and this art is a
  # silhouette -- its ring and its eyes are told apart by colour alone -- so
  # read the same palette fastfetch would out of config.jsonc and apply it.
  local cfg="$HOME/.config/fastfetch/config.jsonc" esc=$'\033' sedp='' n c
  if [ -n "$key" ] && [ -r "$cfg" ]; then
    while IFS='|' read -r n c; do
      [ -n "$n" ] && sedp="$sedp;s/\\\$$n/$esc[${c}m/g"
    done <<< "$(grep -o '"[1-9]"[[:space:]]*:[[:space:]]*"[0-9;]*"' "$cfg" |
                sed 's/"\([1-9]\)"[^"]*"\([0-9;]*\)"/\1|\2/')"
    [ -n "$sedp" ] && sedp="$sedp;s/\$/$esc[0m/"
  fi
  f=$(_alter_logo_file) &&
    sed -e "${sedp#;}" -e 's/\$\([1-9]\)//g' -e 's/\$\$/$/g' -e 's/^/  /' "$f"
  echo

  _row() { printf '  %s%-5s%s %s\n' "$key" "$1" "$off" "$2"; }
  printf '\n  %s%s@%s%s\n' "$key" "${USER:-$(id -un)}" "${host%%.*}" "$off"
  v=$( . /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-unknown}" )
  _row os   "$v $(uname -m)"
  _row ker  "$(uname -sr)"
  command -v uptime >/dev/null && _row up "$(uptime -p 2>/dev/null | sed 's/^up //')"
  _row sh   "bash ${BASH_VERSION%%(*}"
  _row term "${TERM:-?}${XDG_SESSION_TYPE:+ (${XDG_CURRENT_DESKTOP:-?}, $XDG_SESSION_TYPE)}"
  if [ -r /proc/meminfo ]; then
    local total avail
    total=$(awk '/^MemTotal:/ {printf "%.1f", $2/1048576}' /proc/meminfo)
    avail=$(awk '/^MemAvailable:/{printf "%.1f", $2/1048576}' /proc/meminfo)
    _row mem "$(awk -v t="$total" -v a="$avail" 'BEGIN{printf "%.1f GiB / %s GiB", t-a, t}')"
  fi
  command -v df >/dev/null && _row disk "$(df -h --output=used,size / 2>/dev/null | awk 'NR==2{print $1" / "$2}')"
  printf '  %sfastfetch not installed — run ~/alter/install.sh packages for the full banner%s\n' \
    "$dim" "$off"
  unset -f _row
}

# The banner, on demand. Flags go straight to fastfetch (e.g. `fetch --logo none`).
# The blank line belongs here rather than at the end of logo.txt: a trailing
# newline in the art is drawn by fastfetch as one more, empty, logo row, which
# makes the art a row taller than the panel beside it.
fetch() {
  local rc
  if command -v fastfetch >/dev/null; then fastfetch "$@"; rc=$?; else _alter_fetch_plain; rc=$?; fi
  echo
  return $rc
}

# Automatic greeting: once per terminal. Every condition here is a reason NOT
# to print -- a script that sources ~/.bashrc, a pipe or `ssh host cmd` with no
# tty, a shell started from a shell that already greeted, or an opt-out.
#
# The marker holds the tty it printed on, and neither $SHLVL nor a plain flag
# would do. $SHLVL is an absolute depth, so it only identifies the outermost
# shell when the terminal was launched straight from the desktop; anything that
# runs a shell in between (`script`, a test harness, an agent) pushes every real
# terminal past the threshold and the banner silently never appears again. A
# plain inherited flag has the opposite failure: launch a terminal from a shell
# that already greeted -- `ghostty &` from a prompt -- and the new window
# inherits the flag and stays blank, which is a new terminal not greeting.
# The tty is what "this terminal" actually means: a new window is a new pts and
# greets, a `bash` inside this one shares the pts and does not.
_alter_greet() {
  [ "${ALTER_NO_GREETING:-0}" = 1 ] && return 0
  case $- in *i*) ;; *) return 0 ;; esac
  [ -t 1 ] || return 0
  local tty; tty=$(tty 2>/dev/null) || return 0
  [ "${ALTER_GREETED:-}" = "$tty" ] && return 0
  export ALTER_GREETED="$tty"
  fetch
}
_alter_greet
