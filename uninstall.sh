#!/usr/bin/env bash
# Revert alter's GNOME settings to GNOME defaults and unlink its configs.
# Does NOT uninstall apt packages or the font.
set -u
export ALTER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ALTER_ROOT/bootstrap/lib.sh"

hdr "Reverting GNOME keys to defaults"
if is_gnome; then
  for k in switch-to-workspace-{1,2,3,4,left,right,up,down} \
           move-to-workspace-{1,2,3,4,left,right,up,down} \
           move-to-monitor-{left,right,up,down} \
           switch-input-source switch-input-source-backward; do
    run gsettings reset org.gnome.desktop.wm.keybindings "$k" 2>/dev/null
  done
  for i in 1 2 3 4; do
    run gsettings reset org.gnome.shell.keybindings "switch-to-application-$i" 2>/dev/null
    gsettings list-schemas | grep -qx org.gnome.shell.extensions.dash-to-dock &&
      run gsettings reset org.gnome.shell.extensions.dash-to-dock "app-hotkey-$i" 2>/dev/null
  done
  for k in workspaces-only-on-primary dynamic-workspaces edge-tiling; do
    run gsettings reset org.gnome.mutter "$k" 2>/dev/null
  done
  run gsettings reset org.gnome.desktop.wm.preferences num-workspaces 2>/dev/null
  run gsettings reset org.gnome.desktop.default-applications.terminal exec 2>/dev/null
  ok "GNOME keys reset"
fi


hdr "Extensions"
# Put PaperWM's own tiling.js back before touching anything else, so an
# uninstall never leaves a patched third-party extension behind. The patcher
# restores the .alter-orig copy it made and is a no-op when there is none.
_pwm_tiling="$HOME/.local/share/gnome-shell/extensions/paperwm@paperwm.github.com/tiling.js"
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
print("  \033[32m\u2713\033[0m disabled PaperWM / Just Perfection / Clipboard Indicator")
INNER
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
  say "  (extension files left in ~/.local/share/gnome-shell/extensions)"
fi
# PaperWM's keybindings live with its files, which stay behind; put the ones
# 40-extensions.sh changed back to PaperWM's defaults so a later re-enable
# starts stock. (restore-keybinds is left alone: PaperWM replays it itself.)
_pwd="$HOME/.local/share/gnome-shell/extensions/paperwm@paperwm.github.com/schemas"
if [ -d "$_pwd" ]; then
  for k in switch-up-workspace switch-down-workspace move-up-workspace \
           move-down-workspace swap-monitor-left swap-monitor-right \
           center-vertically switch-monitor-{left,right,above,below}; do
    run gsettings --schemadir "$_pwd" reset org.gnome.shell.extensions.paperwm.keybindings "$k" 2>/dev/null
  done
  ok "PaperWM keybindings reset to its defaults"
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
for f in "$HOME/.config/ghostty/config" "$HOME/.config/rofi/config.rasi" \
         "$HOME/.config/rofi/themes/catppuccin-mocha.rasi" \
         "$HOME/.config/shell/devtools.sh" "$HOME/.config/shell/greeting.sh" \
         "$HOME/.config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/logo.txt" \
         "$HOME/.local/bin/zenity-askpass"; do
  if [ -L "$f" ] && readlink -f "$f" | grep -q "^$ALTER_ROOT/"; then
    run rm "$f"; ok "removed $f"
  else skip "$f (not an alter symlink)"; fi
done

hdr "Manual leftovers"
say "  - remove the 'alter' blocks from ~/.bashrc (dev tooling, and the greeting)"
say "  - git config --global --unset-all include.path '$ALTER_ROOT/config/git/gitconfig.include'"
say "  - the rofi custom keybinding: Settings > Keyboard > Custom Shortcuts"
