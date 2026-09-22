#!/usr/bin/env bash
# GNOME desktop settings: workspaces, keybindings, appearance, wallpaper, rofi.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

hdr "GNOME"

if ! is_gnome; then
  warn "not a GNOME session (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset}); skipping"
  return 0 2>/dev/null || exit 0
fi
have gsettings || { err "gsettings not found"; return 1 2>/dev/null || exit 1; }
say "  GNOME Shell $(gnome_ver), session ${XDG_SESSION_TYPE:-unknown}"

# 1..9: GNOME has switch-to-application-N only up to 9, and Super+10 is no key.
WS_COUNT="${ALTER_WS_COUNT:-4}"
case "$WS_COUNT" in
  [1-9]) ;;
  *) warn "ALTER_WS_COUNT=$WS_COUNT is not 1-9; using 4"; WS_COUNT=4 ;;
esac

# ---- workspaces ----
gset org.gnome.mutter workspaces-only-on-primary false
gset org.gnome.mutter dynamic-workspaces false
gset org.gnome.desktop.wm.preferences num-workspaces "$WS_COUNT"
# No edge-tiling here. It is GNOME's default already, and PaperWM
# (40-extensions.sh) forces it false on every load and restores the saved value
# on disable (patches.js saveRuntimeDisable). Setting it true while PaperWM runs
# turns GNOME's snap-to-edge back on underneath the tiler, and every re-run
# would do it again.

# ---- appearance: Catppuccin Mocha is dark with a mauve accent ----
# Yaru-purple-dark is the closest NATIVE match. A third-party GTK theme would
# match more exactly but can break app rendering and rarely survives an
# Ubuntu upgrade cleanly.
gset org.gnome.desktop.interface color-scheme "'prefer-dark'"
gset org.gnome.desktop.interface gtk-theme    "'Yaru-purple-dark'"
gset org.gnome.desktop.interface icon-theme   "'Yaru-purple'"
if gsettings list-schemas 2>/dev/null | grep -qx org.gnome.shell.extensions.dash-to-dock; then
  gset org.gnome.shell.extensions.dash-to-dock background-opacity 0.6
fi

# ---- one wallpaper across every monitor, not a copy per screen ----
# picture-options decides this, not the image and not the monitor layout.
# Every other value -- zoom, scaled, stretched, centered -- is applied to each
# monitor independently, so a dual-head setup gets its own separately-scaled
# copy of the picture on each screen. 'spanned' is the only value that treats
# the monitors as a single surface and slices one image across them.
# Safe unconditionally: with one monitor 'spanned' has nothing to span and
# behaves like zoom, so there is no need to count displays before setting it.
# Wants a picture at least as wide as the combined desktop (here 2x2560 =
# 5120px) or the slice on each screen is an upscale.
gset org.gnome.desktop.background picture-options "'spanned'"

# ---- free Super+1..N from app-switching and the Ubuntu dock ----
for i in $(seq 1 "$WS_COUNT"); do
  gset org.gnome.shell.keybindings "switch-to-application-$i" "@as []"
  if gsettings list-schemas 2>/dev/null | grep -qx org.gnome.shell.extensions.dash-to-dock; then
    gset org.gnome.shell.extensions.dash-to-dock "app-hotkey-$i" "@as []"
  fi
done

# ---- Super+N -> workspace N, Super+Shift+N -> move window there ----
for i in $(seq 1 "$WS_COUNT"); do
  gset org.gnome.desktop.wm.keybindings "switch-to-workspace-$i" "['<Super>$i']"
  gset org.gnome.desktop.wm.keybindings "move-to-workspace-$i"   "['<Super><Shift>$i']"
done

# ---- workspace prev/next: Super+Alt+arrows, and nothing else ----
# GNOME ships three aliases per direction -- switch-to-workspace-left defaults
# to ['<Super>Page_Up','<Super><Alt>Left','<Control><Alt>Left']. One binding is
# enough: three rows for one action makes `keys` noisy, and it needlessly holds
# Ctrl+Alt+arrows and Super+PgUp/PgDn hostage. Super+Alt+arrows is the keeper --
# it is Super-prefixed like the rest of this repo's desktop keys, and unlike
# Ctrl+Alt+arrows no terminal wants it.
# Up/down go empty: GNOME 40+ lays workspaces out in a horizontal strip, so
# there is nothing above or below to switch to.
gset org.gnome.desktop.wm.keybindings switch-to-workspace-left  "['<Super><Alt>Left']"
gset org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Super><Alt>Right']"
gset org.gnome.desktop.wm.keybindings switch-to-workspace-up    "@as []"
gset org.gnome.desktop.wm.keybindings switch-to-workspace-down  "@as []"
gset org.gnome.desktop.wm.keybindings move-to-workspace-up      "@as []"
gset org.gnome.desktop.wm.keybindings move-to-workspace-down    "@as []"

# ---- move window to prev/next workspace: Super+Shift+Left/Right ----
# Moving a window is used far more than focusing the other monitor, so it gets
# the two-modifier chord; PaperWM's switch-monitor moves to Super+Shift+Alt
# (40-extensions.sh). GNOME ships move-to-monitor-* on Super+Shift+arrows, so
# all four are emptied: left/right would collide with the binding below, and
# up/down are emptied with them so Super+Shift+Up/Down do not quietly start
# moving windows between monitors. PaperWM's move-monitor (Super+Shift+Ctrl+
# arrows) still does that job.
gset org.gnome.desktop.wm.keybindings move-to-workspace-left    "['<Super><Shift>Left']"
gset org.gnome.desktop.wm.keybindings move-to-workspace-right   "['<Super><Shift>Right']"
for d in left right up down; do
  gset org.gnome.desktop.wm.keybindings "move-to-monitor-$d" "@as []"
done

# ---- Super+Space -> rofi window switcher ----
# Only safe to take if there is a single input source; otherwise Super+Space
# is a live input-method toggle and we leave it alone.
SRC_COUNT=$(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null | grep -o "('xkb'\|('ibus'" | wc -l)
ROFI_KEY="${ALTER_ROFI_KEY:-}"
if [ -z "$ROFI_KEY" ]; then
  if [ "$SRC_COUNT" -le 1 ]; then ROFI_KEY='<Super>space'; else ROFI_KEY='<Super>w'; fi
fi
if [ "$ROFI_KEY" = '<Super>space' ]; then
  gset org.gnome.desktop.wm.keybindings switch-input-source          "@as []"
  gset org.gnome.desktop.wm.keybindings switch-input-source-backward "@as []"
elif [ -n "${ALTER_ROFI_KEY:-}" ]; then
  say "  rofi on $ROFI_KEY (ALTER_ROFI_KEY); input-source keys left alone"
else
  warn "$SRC_COUNT input sources present; using $ROFI_KEY for rofi instead of Super+Space"
fi

BASE=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings
SCHEMA=org.gnome.settings-daemon.plugins.media-keys.custom-keybinding
NAME='Rofi window switcher'

# Find an existing slot with our name, else claim the first free index.
cur=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null)
slot=""
for p in $(printf '%s' "$cur" | grep -oE "$BASE/[^/']+/"); do
  n=$(gsettings get "$SCHEMA:$p" name 2>/dev/null | tr -d "'")
  [ "$n" = "$NAME" ] && { slot="$p"; break; }
done
if [ -z "$slot" ]; then
  for i in $(seq 0 49); do
    case "$cur" in *"$BASE/custom$i/"*) continue;; esac
    slot="$BASE/custom$i/"; break
  done
  if [ "$cur" = "@as []" ] || [ -z "$cur" ]; then newlist="['$slot']"
  else newlist=$(printf '%s' "$cur" | sed "s|]$|, '$slot']|"); fi
  run gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$newlist"
  ok "registered custom keybinding slot $slot"
else
  skip "reusing existing slot $slot"
fi
gset "$SCHEMA:$slot" name    "'$NAME'"
gset "$SCHEMA:$slot" command "'rofi -show window'"
gset "$SCHEMA:$slot" binding "'$ROFI_KEY'"
