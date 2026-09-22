#!/usr/bin/env bash
# Revert alter's GNOME settings to GNOME defaults, unlink its configs and
# unhook the shell. Does NOT uninstall apt packages, PPAs, the font or the
# extension files -- see "Manual leftovers" at the end.
#   DRY_RUN=1 ./uninstall.sh      show what would be reverted, touch nothing
set -u
export ALTER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ALTER_ROOT/bootstrap/lib.sh"

EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
PWM=paperwm@paperwm.github.com

# Extensions go first. When PaperWM is disabled it replays what it saved on
# enable -- restore-keybinds, and the mutter keys it forces off at runtime
# (restore-{edge-tiling,workspaces-only-on-primary,attach-modal-dialogs}) --
# and any reset made while it was still running would be overwritten by that.
hdr "Extensions"
# Put PaperWM's own tiling.js back before touching anything else, so an
# uninstall never leaves a patched third-party extension behind. The patcher
# restores the .alter-orig copy it made and is a no-op when there is none.
_pwm_tiling="$EXT_DIR/$PWM/tiling.js"
if [ -f "$_pwm_tiling.alter-orig" ]; then
  # The patcher prints its own confirmation on a real run; no `&& ok` here,
  # because `run` succeeds under --dry-run and would claim a restore that
  # never happened.
  run python3 "$ALTER_ROOT/bootstrap/paperwm-picture-options.py" revert "$_pwm_tiling"
else
  skip "PaperWM tiling.js not patched by alter"
fi
if [ "${DRY_RUN:-0}" = 1 ]; then
  printf '  \033[2m[dry-run]\033[0m disable PaperWM / Just Perfection / Clipboard Indicator\n'
  printf '  \033[2m[dry-run]\033[0m re-enable tiling-assistant@ubuntu.com (drop from disabled-extensions)\n'
  printf '  \033[2m[dry-run]\033[0m reset org.gnome.shell disable-user-extensions\n'
elif is_gnome; then
  python3 - <<'INNER'
import subprocess, ast
ours=["paperwm@paperwm.github.com","just-perfection-desktop@just-perfection","clipboard-indicator@tudmotu.com"]
cur=ast.literal_eval(subprocess.check_output(["gsettings","get","org.gnome.shell","enabled-extensions"],text=True).strip().replace("@as ",""))
new=[e for e in cur if e not in ours]
subprocess.run(["gsettings","set","org.gnome.shell","enabled-extensions","["+", ".join("'%s'"%e for e in new)+"]"],check=True)
print("  \033[32m✓\033[0m disabled PaperWM / Just Perfection / Clipboard Indicator")
INNER
  # The shell reacts to that write asynchronously; give PaperWM up to 10s to
  # run its disable() and replay its saved values before the resets below.
  for _ in $(seq 1 20); do
    case "$(gnome-extensions info "$PWM" 2>/dev/null | awk -F': ' '/State:/{print $2}')" in
      ACTIVE|ENABLED) sleep 0.5 ;;
      *) break ;;
    esac
  done
  # Ubuntu's own extensions are enabled by default and are turned off through
  # `disabled-extensions`, not `enabled-extensions` -- so putting tiling-assistant
  # back means dropping it from the disabled list, not adding it to the enabled one.
  if gnome-extensions info tiling-assistant@ubuntu.com >/dev/null 2>&1; then
    run gnome-extensions enable tiling-assistant@ubuntu.com &&
      ok "re-enabled Ubuntu Tiling Assistant"
  else
    skip "tiling-assistant not installed"
  fi
  # 40-extensions.sh sets this false so user extensions can load at all. GNOME's
  # own default is false too, so a reset simply drops the explicit setting.
  run gsettings reset org.gnome.shell disable-user-extensions 2>/dev/null
  ok "disable-user-extensions reset to the GNOME default"
fi
# PaperWM's keybindings live with its files, which stay behind; put the ones
# 40-extensions.sh changed back to PaperWM's defaults so a later re-enable
# starts stock. (restore-keybinds is left alone: PaperWM replays it itself.)
_pwd="$EXT_DIR/$PWM/schemas"
if [ -d "$_pwd" ]; then
  for k in switch-up-workspace switch-down-workspace move-up-workspace \
           move-down-workspace swap-monitor-left swap-monitor-right \
           center-vertically switch-monitor-{left,right,above,below}; do
    run gsettings --schemadir "$_pwd" reset org.gnome.shell.extensions.paperwm.keybindings "$k" 2>/dev/null
  done
  ok "PaperWM keybindings reset to its defaults"
fi

hdr "Reverting GNOME keys to defaults"
if is_gnome; then
  _dock=0; gsettings list-schemas 2>/dev/null | grep -qx org.gnome.shell.extensions.dash-to-dock && _dock=1
  for k in switch-to-workspace-{left,right,up,down} \
           move-to-workspace-{left,right,up,down} \
           move-to-monitor-{left,right,up,down} \
           switch-input-source switch-input-source-backward; do
    run gsettings reset org.gnome.desktop.wm.keybindings "$k" 2>/dev/null
  done
  # 1..9 whatever ALTER_WS_COUNT install.sh ran with (20-gnome.sh caps it at
  # 9); resetting a key that is already at its default is a no-op.
  for i in $(seq 1 9); do
    run gsettings reset org.gnome.desktop.wm.keybindings "switch-to-workspace-$i" 2>/dev/null
    run gsettings reset org.gnome.desktop.wm.keybindings "move-to-workspace-$i" 2>/dev/null
    run gsettings reset org.gnome.shell.keybindings "switch-to-application-$i" 2>/dev/null
    [ "$_dock" = 1 ] && run gsettings reset org.gnome.shell.extensions.dash-to-dock "app-hotkey-$i" 2>/dev/null
  done
  # edge-tiling is not here: alter never sets it, and PaperWM's disable above
  # puts back whatever value it found.
  for k in workspaces-only-on-primary dynamic-workspaces; do
    run gsettings reset org.gnome.mutter "$k" 2>/dev/null
  done
  run gsettings reset org.gnome.desktop.wm.preferences num-workspaces 2>/dev/null
  run gsettings reset org.gnome.desktop.default-applications.terminal exec 2>/dev/null
  ok "GNOME keys reset"

  # The rofi custom keybinding 20-gnome.sh registered, found by its name.
  MK=org.gnome.settings-daemon.plugins.media-keys
  _cur=$(gsettings get "$MK" custom-keybindings 2>/dev/null)
  _slot=""
  for p in $(printf '%s' "$_cur" | grep -oE "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/[^/']+/"); do
    [ "$(gsettings get "$MK.custom-keybinding:$p" name 2>/dev/null)" = "'Rofi window switcher'" ] && { _slot="$p"; break; }
  done
  if [ -n "$_slot" ]; then
    _new=$(CUR="$_cur" SLOT="$_slot" python3 -c '
import ast, os
l = [p for p in ast.literal_eval(os.environ["CUR"].replace("@as ", "")) if p != os.environ["SLOT"]]
print("[" + ", ".join("%r" % p for p in l) + "]" if l else "@as []")')
    run gsettings set "$MK" custom-keybindings "$_new"
    for k in name command binding; do
      run gsettings reset "$MK.custom-keybinding:$_slot" "$k" 2>/dev/null
    done
    ok "removed the rofi custom keybinding ($_slot)"
  else
    skip "no 'Rofi window switcher' custom keybinding"
  fi
fi

hdr "Appearance"
if is_gnome; then
  for k in color-scheme gtk-theme icon-theme; do
    run gsettings reset org.gnome.desktop.interface "$k" 2>/dev/null
  done
  gsettings list-schemas | grep -qx org.gnome.shell.extensions.dash-to-dock &&
    run gsettings reset org.gnome.shell.extensions.dash-to-dock background-opacity 2>/dev/null
  # Back to the GNOME default (zoom): one copy of the picture per monitor.
  # Resets the layout only -- the chosen wallpaper (picture-uri) is the user's
  # and this repo never set it, so it is left exactly as it is.
  run gsettings reset org.gnome.desktop.background picture-options 2>/dev/null
  ok "appearance reset to Ubuntu defaults"
fi

hdr "Unlinking configs"
# Every `link` in 30-dotfiles.sh.
for f in "$HOME/.config/ghostty/config" "$HOME/.config/rofi/config.rasi" \
         "$HOME/.config/rofi/themes/catppuccin-mocha.rasi" \
         "$HOME/.config/shell/devtools.sh" "$HOME/.config/shell/greeting.sh" \
         "$HOME/.config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/logo.txt" \
         "$HOME/.config/bat/themes/Catppuccin Mocha.tmTheme" \
         "$HOME/.local/bin/zenity-askpass"; do
  if [ -L "$f" ] && readlink -f "$f" | grep -q "^$ALTER_ROOT/"; then
    run rm "$f"; ok "removed $f"
  else skip "$f (not an alter symlink)"; fi
done
# Drop the unlinked theme from bat's cache too.
_bat=$(command -v batcat || command -v bat) || true
if [ -n "${_bat:-}" ] && "$_bat" --list-themes 2>/dev/null | grep -qx "Catppuccin Mocha"; then
  runq "$_bat" cache --build && ok "bat cache rebuilt without Catppuccin Mocha"
fi

hdr "Shell hooks"
# The source lines 30-dotfiles.sh appends, each with the `# --- ... ---` comment
# above it and the blank line above that. Matched on the source line, not the
# comment, so older wordings of the comment go too. ~/.bashrc is backed up
# first and written in place, so a symlinked ~/.bashrc stays a symlink.
_hook='^\[ -f "\$HOME/\.config/shell/(devtools|greeting)\.sh" \] && \. "\$HOME/\.config/shell/(devtools|greeting)\.sh"$'
if grep -qE "$_hook" "$HOME/.bashrc" 2>/dev/null; then
  if [ "$DRY_RUN" = 1 ]; then
    printf '  %s[dry-run]%s remove the alter hooks from %s\n' "$c_dim" "$c_off" "$HOME/.bashrc"
  else
    mkdir -p "$ALTER_BACKUP" && cp -p "$HOME/.bashrc" "$ALTER_BACKUP/.bashrc" &&
    HOOK="$_hook" python3 - "$HOME/.bashrc" <<'PY' && ok "removed the alter hooks from ~/.bashrc (backup in $ALTER_BACKUP)"
import os, re, sys
path = sys.argv[1]
hook = re.compile(os.environ["HOOK"])
out = []
for line in open(path, encoding="utf-8").read().split("\n"):
    if hook.match(line):
        if out and out[-1].startswith("# --- "): out.pop()
        if out and out[-1].strip() == "": out.pop()
        continue
    out.append(line)
open(path, "w", encoding="utf-8").write("\n".join(out))
PY
  fi
else
  skip "~/.bashrc has no alter hooks"
fi

hdr "git"
_inc="$ALTER_ROOT/config/git/gitconfig.include"
if git config --global --get-all include.path 2>/dev/null | grep -qxF "$_inc"; then
  run git config --global --fixed-value --unset-all include.path "$_inc" &&
    ok "git: removed include.path $_inc" ||
    warn "could not remove it (git < 2.30?); edit ~/.gitconfig by hand"
else
  skip "git include not present"
fi

hdr "Default terminal"
# 30-dotfiles.sh writes these as a single line. Anything else in them was put
# there by someone else (GNOME Terminal, the user) and is left alone.
_lists=("$HOME/.config/xdg-terminals.list")
[ -n "${XDG_CURRENT_DESKTOP:-}" ] && _lists+=("$HOME/.config/${XDG_CURRENT_DESKTOP%%:*}-xdg-terminals.list")
for f in "${_lists[@]}"; do
  if [ "$(cat "$f" 2>/dev/null)" = com.mitchellh.ghostty.desktop ]; then
    run rm "$f"; ok "removed $f"
  elif [ -f "$f" ]; then
    skip "$f (has entries alter did not write; left alone)"
  fi
done

hdr "Manual leftovers"
say "  - ~/.bash_profile's 'alter: chain to ~/.bashrc' block (harmless; keeps login shells reading ~/.bashrc)"
say "  - extension files and their settings: gnome-extensions uninstall <uuid>"
say "  - apt packages, the ghostty / fastfetch PPAs (add-apt-repository --remove), the Nerd Font"
