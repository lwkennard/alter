# Shared helpers. Sourced by every bootstrap module.
set -u   # NOT pipefail: `cmd | grep -q` SIGPIPEs the producer and pipefail would report a false failure

ALTER_ROOT="${ALTER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ALTER_BACKUP="${ALTER_BACKUP:-$HOME/.local/share/alter-backup/$(date +%Y%m%d-%H%M%S)}"
DRY_RUN="${DRY_RUN:-0}"

c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_err=$'\033[31m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
say()  { printf '%s\n' "$*"; }
ok()   { printf '  %s✓%s %s\n' "$c_ok"   "$c_off" "$*"; }
warn() { printf '  %s!%s %s\n' "$c_warn" "$c_off" "$*"; }
err()  { printf '  %s✗%s %s\n' "$c_err"  "$c_off" "$*" >&2; }
skip() { printf '  %s·%s %s\n' "$c_dim"  "$c_off" "$*"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

run() {
  if [ "$DRY_RUN" = 1 ]; then printf '  %s[dry-run]%s %s\n' "$c_dim" "$c_off" "$*"; return 0; fi
  "$@"
}
# `run`, with the command's own output discarded. Use this instead of
# `run cmd >/dev/null`: that redirect would swallow the [dry-run] line too.
runq() {
  if [ "$DRY_RUN" = 1 ]; then run "$@"; else "$@" >/dev/null 2>&1; fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# Distro / session detection
os_id()        { . /etc/os-release 2>/dev/null && echo "${ID:-unknown}"; }
os_codename()  { . /etc/os-release 2>/dev/null && echo "${VERSION_CODENAME:-unknown}"; }
is_debianish() { [ -f /etc/debian_version ]; }
is_gnome()     { case "${XDG_CURRENT_DESKTOP:-}" in *GNOME*) return 0;; *) return 1;; esac; }
gnome_ver()    { have gnome-shell && gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo 0; }

# Symlink $2 -> $1, backing up anything already there.
link() {
  local src="$1" dst="$2"
  [ -e "$src" ] || { err "missing source: $src"; return 1; }
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    skip "$dst (already linked)"; return 0
  fi
  run mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    run mkdir -p "$ALTER_BACKUP/$(dirname "${dst#$HOME/}")"
    run mv "$dst" "$ALTER_BACKUP/${dst#$HOME/}"
    warn "backed up existing $dst"
  fi
  run ln -s "$src" "$dst"
  ok "$dst -> $src"
}

# Append a block to a file exactly once, keyed by a marker string.
append_once() {
  local file="$1" marker="$2" block="$3"
  if grep -qF "$marker" "$file" 2>/dev/null; then skip "$file (hook present)"; return 0; fi
  if [ "$DRY_RUN" = 1 ]; then printf '  %s[dry-run]%s append to %s\n' "$c_dim" "$c_off" "$file"; return 0; fi
  printf '%s\n' "$block" >> "$file"
  ok "hooked into $file"
}

# gsettings set, but only report when the value actually changes.
gset() {
  local schema="$1" key="$2" val="$3" cur
  cur="$(gsettings get "$schema" "$key" 2>/dev/null)" || { warn "no such key: $schema $key"; return 0; }
  # Doubles round-trip lossily (0.6 -> 0.59999999999999998), so compare
  # numerically when both sides are plain numbers, else string-compare.
  if [ "$cur" = "$val" ] ||
     { case "$cur$val" in *[!0-9.\ -]*) false;; *) awk -v a="$cur" -v b="$val" 'BEGIN{exit !(a-b<1e-9 && b-a<1e-9)}';; esac; }; then
    skip "$key (already $cur)"; return 0
  fi
  run gsettings set "$schema" "$key" "$val" || { warn "failed: $schema $key"; return 0; }
  ok "$key: $cur -> $val"
}

