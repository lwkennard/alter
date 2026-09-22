#!/usr/bin/env bash
# GNOME Shell extensions: PaperWM, Just Perfection, Clipboard Indicator.
# Downloads from extensions.gnome.org, installs, enables and configures them.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

hdr "GNOME extensions"

if ! is_gnome; then
  warn "not a GNOME session; skipping extensions"
  return 0 2>/dev/null || exit 0
fi
have gnome-extensions || { err "gnome-extensions CLI not found"; return 1 2>/dev/null || exit 1; }
have curl || { err "curl not found"; return 1 2>/dev/null || exit 1; }

SHELL_MAJOR="$(gnome_ver)"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
WANT=(
  paperwm@paperwm.github.com
  just-perfection-desktop@just-perfection
  clipboard-indicator@tudmotu.com
)
# PaperWM does the tiling now; Ubuntu's snap-assist fights it.
CONFLICTS=(tiling-assistant@ubuntu.com)

# ---- install any that are missing ----
for uuid in "${WANT[@]}"; do
  if [ -d "$EXT_DIR/$uuid" ]; then skip "$uuid (installed)"; continue; fi
  info=$(curl -fsS --connect-timeout 25 \
    "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${SHELL_MAJOR}" 2>/dev/null) || {
      warn "$uuid: no release for GNOME $SHELL_MAJOR -- skipping"; continue; }
  dl=$(printf '%s' "$info" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("download_url",""))' 2>/dev/null)
  [ -n "$dl" ] || { warn "$uuid: no download_url"; continue; }
  tmp="$(mktemp -d)"
  if run curl -fsSL --connect-timeout 30 -o "$tmp/e.zip" "https://extensions.gnome.org${dl}" &&
     run gnome-extensions install --force "$tmp/e.zip"; then
    ok "installed $uuid"
  else
    warn "failed to install $uuid"
  fi
  rm -rf "$tmp"
done

# ---- the master switch ----
# `disable-user-extensions` is a global kill switch for everything under
# ~/.local/share/gnome-shell/extensions. GNOME's own gschema says it "takes
# precedence over the enabled-extensions setting" -- so while it is true, every
# extension below installs, lists as enabled, and still never loads. GNOME
# Settings' Extensions toggle and gnome-shell's own crash-recovery both set it,
# so a machine can acquire it without anyone choosing it.
gset org.gnome.shell disable-user-extensions false

# ---- enable ours, in one gsettings write ----
  python3 - "$DRY_RUN" "$EXT_DIR" "${WANT[@]}" -- "${CONFLICTS[@]}" <<'PY'
import subprocess, ast, sys, os
dry = sys.argv[1] == "1"
ext_dir = sys.argv[2]
rest = sys.argv[3:]
sep = rest.index("--")
want, conflicts = rest[:sep], rest[sep+1:]
cur = ast.literal_eval(subprocess.check_output(
    ["gsettings","get","org.gnome.shell","enabled-extensions"], text=True).strip().replace("@as ",""))
new = [e for e in cur if e not in conflicts]
for e in want:
    if e not in new and os.path.isdir(os.path.join(ext_dir, e)):
        new.append(e)
if new != cur:
    if dry:
        print("  \033[2m[dry-run]\033[0m set enabled-extensions to %d entries" % len(new))
    else:
        subprocess.run(["gsettings","set","org.gnome.shell","enabled-extensions",
                        "["+", ".join("'%s'"%e for e in new)+"]"], check=True)
        print("  \033[32m✓\033[0m enabled-extensions updated")
else:
    print("  \033[2m·\033[0m enabled-extensions already correct")
PY

# ---- conflicts ----
# Ubuntu's own extensions live in /usr/share and are enabled by DEFAULT: they
# never appear in `enabled-extensions`, so dropping them from that list does
# nothing at all. The key that actually turns one off is `disabled-extensions`,
# which is what `gnome-extensions disable` writes.
for uuid in "${CONFLICTS[@]}"; do
  _st="$(gnome-extensions info "$uuid" 2>/dev/null | awk -F': ' '/Enabled:/{print $2}')"
  case "$_st" in
    "")  skip "$uuid (not installed)" ;;
    No)  skip "$uuid (already disabled)" ;;
    *)   run gnome-extensions disable "$uuid" && ok "disabled $uuid (conflicts with PaperWM)" ;;
  esac
done

# ---- configuration (schemas live under each extension) ----
xset() {  # xset <uuid> <schema> <key> <value>
  local d="$EXT_DIR/$1/schemas"
  [ -d "$d" ] || { skip "$1 not installed; skipping $3"; return 0; }
  local cur; cur="$(gsettings --schemadir "$d" get "$2" "$3" 2>/dev/null)" || { warn "no key $2 $3"; return 0; }
  # Doubles round-trip lossily (0.18 -> 0.17999999999999999), so compare
  # numerically when both sides look like plain numbers.
  if [ "$cur" = "$4" ] || { case "$cur$4" in *[!0-9.\ -]*) false;; *) awk -v a="$cur" -v b="$4" 'BEGIN{exit !(a-b<1e-9 && b-a<1e-9)}';; esac; }; then
    skip "$3 (already set)"; return 0
  fi
  run gsettings --schemadir "$d" set "$2" "$3" "$4" && ok "$3"
}

P=org.gnome.shell.extensions.paperwm
PU=paperwm@paperwm.github.com
xset $PU $P window-gap 14
xset $PU $P horizontal-margin 14
xset $PU $P vertical-margin 14
xset $PU $P vertical-margin-bottom 14
xset $PU $P selection-border-size 4
xset $PU $P selection-border-radius-top 10
xset $PU $P selection-border-radius-bottom 10
xset $PU $P animation-time 0.18
xset $PU $P show-workspace-indicator true
xset $PU $P workspace-colors "['#cba6f7', '#89b4fa', '#a6e3a1', '#fab387', '#f5c2e7', '#94e2d5', '#f9e2af', '#b4befe', '#f38ba8', '#89dceb', '#74c7ec', '#eba0ac', '#f2cdcd', '#f5e0dc', '#585b70', '#45475a', '#313244', '#1e1e2e']"

J=org.gnome.shell.extensions.just-perfection
JU=just-perfection-desktop@just-perfection
xset $JU $J startup-status 0
xset $JU $J window-demands-attention-focus true
xset $JU $J workspace-wrap-around true
xset $JU $J double-super-to-appgrid false
xset $JU $J animation 3

C=org.gnome.shell.extensions.clipboard-indicator
CU=clipboard-indicator@tudmotu.com
xset $CU $C toggle-menu "['<Super>v']"
xset $CU $C history-size 50
xset $CU $C move-item-first true
xset $CU $C preview-size 45

say ""
warn "New extensions only load after a GNOME Shell restart."
say  "    X11:     Alt+F2, type 'r', Enter"
say  "    Wayland: log out and back in"

# ---- make PaperWM yield the keys 20-gnome.sh already assigned ----
# PaperWM ships 100 bindings; four collide with this repo's desktop keys.
# 20-gnome.sh deliberately picks Super+Alt+arrows as the ONE workspace
# prev/next binding, so PaperWM's duplicates go rather than GNOME's:
#   switch-{up,down}-workspace  Super+PgUp/PgDn   -> duplicate of Super+Alt+arrows
#   move-{up,down}-workspace    Super+Ctrl+PgUp/Dn-> duplicate of Super+Shift+Left/Right
#   swap-monitor-{left,right}   Super+Alt+L/R     -> would steal workspace prev/next
#   center-vertically           Super+V           -> Clipboard Indicator owns it
# swap-monitor-{above,below} (Super+Alt+Up/Down) survives: GNOME's up/down are
# empty, because GNOME 40+ lays workspaces out horizontally.
# center-vertically has to go rather than move: this stage sets Clipboard
# Indicator's toggle-menu to Super+V and docs/hotkeys.txt documents that key as
# clipboard history. Super+C (centre horizontally) is the one that stays.
PWK=org.gnome.shell.extensions.paperwm.keybindings
for k in switch-up-workspace switch-down-workspace \
         move-up-workspace move-down-workspace \
         swap-monitor-left swap-monitor-right \
         center-vertically; do
  xset $PU $PWK "$k" "@as []"
done

# ---- Super+Shift+Left/Right belongs to GNOME's move-to-workspace ----
# 20-gnome.sh gives move-window-to-prev/next-workspace the Super+Shift chord,
# so PaperWM's switch-monitor (focus the other monitor) steps up to
# Super+Shift+Alt. Up/down move with it to keep the family on one modifier set.
#
# Moving the keys is not enough on its own. When PaperWM first claimed
# Super+Shift+arrows it emptied GNOME's move-to-monitor-* and saved the stock
# values in its `restore-keybinds` key. It replays that list on every shell
# start and on every change to one of its own keys -- including the change
# just below -- so move-to-monitor-left would come back on Super+Shift+Left and
# collide with move-to-workspace-left. Drop those four entries first, so there
# is nothing to replay; uninstall.sh resets them to stock itself.
# move-to-workspace-* goes too: PaperWM also watches GNOME's keybinding schemas,
# so on a machine where it still held Super+Shift+Left/Right, 20-gnome.sh's
# write gets emptied and queued here. The rebind below restores it, but PaperWM
# writes back a stale copy of the list, so the entry stays -- and on disable it
# would re-apply Super+Shift+Left after uninstall.sh reset the key to stock.
# That queueing lands after this scrub, so the first run on such a machine can
# leave it behind; the second run removes it (verify.sh flags it meanwhile).
PWS="$EXT_DIR/$PU/schemas"
if [ -d "$PWS" ]; then
  _rk=$(gsettings --schemadir "$PWS" get $P restore-keybinds 2>/dev/null) || _rk=""
  case "$_rk" in
    *'"move-to-monitor-'*|*'"move-to-workspace-'*)
      if [ "$DRY_RUN" = 1 ]; then
        printf '  %s[dry-run]%s drop move-to-{monitor,workspace}-* from PaperWM restore-keybinds\n' "$c_dim" "$c_off"
      else
        _new=$(RK="$_rk" python3 -c '
import ast, json, os
d = json.loads(ast.literal_eval(os.environ["RK"]))
for k in [k for k in d if k.startswith(("move-to-monitor-", "move-to-workspace-"))]:
    del d[k]
print(json.dumps(d, separators=(",", ":")))') &&
          gsettings --schemadir "$PWS" set $P restore-keybinds "$_new" &&
          ok "PaperWM will no longer restore move-to-{monitor,workspace}-*"
      fi ;;
    *) skip "PaperWM restore-keybinds has no move-to-{monitor,workspace}-* (already clean)" ;;
  esac
fi
xset $PU $PWK switch-monitor-left  "['<Super><Shift><Alt>Left']"
xset $PU $PWK switch-monitor-right "['<Super><Shift><Alt>Right']"
xset $PU $PWK switch-monitor-above "['<Super><Shift><Alt>Up']"
xset $PU $PWK switch-monitor-below "['<Super><Shift><Alt>Down']"

# ---- make PaperWM honour picture-options (one wallpaper across all monitors) ----
# PaperWM does not let GNOME draw the desktop. Every space builds its own
# Meta.BackgroundActor *per monitor* and tiling.js passes a hardcoded
# GDesktopEnums.BackgroundStyle.ZOOM. While PaperWM is active that makes EVERY
# value of org.gnome.desktop.background picture-options a no-op -- spanned,
# centered and stretched all render as one zoomed copy on each screen -- whether
# it is set with gsettings, GNOME Settings or GNOME Tweaks. 20-gnome.sh sets
# 'spanned'; this patch is what lets that setting reach the screen.
# Upstream as of PaperWM v148 / 50.0.1. A PaperWM update overwrites tiling.js
# and silently restores the per-monitor copies, so this re-applies on every run
# and verify.sh checks it. The patcher refuses to touch a tiling.js whose
# anchors it does not recognise, so a restructured upstream fails loudly here
# rather than silently producing a broken extension.
PWM_TILING="$EXT_DIR/$PU/tiling.js"
PWM_PATCHER="$ALTER_ROOT/bootstrap/paperwm-picture-options.py"
if [ ! -f "$PWM_TILING" ]; then
  skip "PaperWM not installed; nothing to patch for picture-options"
elif python3 "$PWM_PATCHER" check "$PWM_TILING" >/dev/null 2>&1; then
  skip "PaperWM already honours picture-options"
elif run python3 "$PWM_PATCHER" apply "$PWM_TILING"; then
  if [ "$DRY_RUN" != 1 ]; then
    ok "PaperWM now honours picture-options"
    warn "restart GNOME Shell to pick it up (X11: Alt+F2, type r, Enter)"
  fi
else
  warn "could not patch PaperWM tiling.js; wallpaper stays one copy per monitor"
fi
