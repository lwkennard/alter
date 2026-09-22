#!/usr/bin/env bash
# alter -- workstation bootstrap.
#   ./install.sh              run everything
#   ./install.sh --dry-run    show what would change, touch nothing
#   ./install.sh gnome only   run a subset (packages|starship|fonts|gnome|dotfiles|extensions|verify)
set -u
export ALTER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ALTER_ROOT/bootstrap/lib.sh"

STAGES=(packages starship fonts gnome dotfiles extensions verify)
declare -A MOD=(
  [packages]=00-packages.sh [starship]=05-starship.sh [fonts]=10-fonts.sh
  [gnome]=20-gnome.sh [dotfiles]=30-dotfiles.sh
  [extensions]=40-extensions.sh [verify]=verify.sh
)

want=()
for a in "$@"; do
  case "$a" in
    --dry-run|-n) export DRY_RUN=1 ;;
    --help|-h) sed -n '2,5p' "$0" | sed 's/^# \?//'; exit 0 ;;
    only) ;;
    *) [ -n "${MOD[$a]:-}" ] && want+=("$a") || { err "unknown stage: $a"; exit 2; } ;;
  esac
done
[ ${#want[@]} -eq 0 ] && want=("${STAGES[@]}")

printf '\033[1malter\033[0m  %s %s / GNOME %s / %s\n' \
  "$(os_id)" "$(os_codename)" "$(gnome_ver)" "${XDG_SESSION_TYPE:-?}"
[ "${DRY_RUN:-0}" = 1 ] && warn "DRY RUN -- nothing will be modified"
say "backups -> $ALTER_BACKUP"

rc=0
for s in "${want[@]}"; do
  ( . "$ALTER_ROOT/bootstrap/${MOD[$s]}" ) || { rc=$?; [ "$s" = verify ] || err "stage '$s' returned $rc"; }
done

hdr "Done"
say "  Log out and back in for the GNOME changes to fully apply."
say "  Hotkeys:    cat $ALTER_ROOT/docs/hotkeys.txt   (or the 'keys' alias)"
[ -d "$ALTER_BACKUP" ] && say "  Replaced files were saved to $ALTER_BACKUP"
exit "$rc"
