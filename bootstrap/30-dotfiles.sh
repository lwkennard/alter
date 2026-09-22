#!/usr/bin/env bash
# Symlink configs out of the repo, hook the shell, wire up git-delta.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

hdr "Dotfiles"

link "$ALTER_ROOT/config/ghostty/config"                    "$HOME/.config/ghostty/config"
link "$ALTER_ROOT/config/rofi/config.rasi"                  "$HOME/.config/rofi/config.rasi"
link "$ALTER_ROOT/config/rofi/themes/catppuccin-mocha.rasi" "$HOME/.config/rofi/themes/catppuccin-mocha.rasi"
link "$ALTER_ROOT/config/shell/devtools.sh"                 "$HOME/.config/shell/devtools.sh"
link "$ALTER_ROOT/config/shell/greeting.sh"                 "$HOME/.config/shell/greeting.sh"
link "$ALTER_ROOT/config/fastfetch/config.jsonc"            "$HOME/.config/fastfetch/config.jsonc"
link "$ALTER_ROOT/config/fastfetch/logo.txt"                "$HOME/.config/fastfetch/logo.txt"
link "$ALTER_ROOT/bin/zenity-askpass"                       "$HOME/.local/bin/zenity-askpass"

append_once "$HOME/.bashrc" 'config/shell/devtools.sh' \
'
# --- alter: dev tooling (fzf / zoxide / fd / bat / eza) ---
[ -f "$HOME/.config/shell/devtools.sh" ] && . "$HOME/.config/shell/devtools.sh"'

# Sourced after devtools.sh so the banner is the last thing a new terminal
# prints. It no-ops unless the shell is interactive, on a tty and outermost.
append_once "$HOME/.bashrc" 'config/shell/greeting.sh' \
'
# --- alter: new-terminal greeting (fastfetch banner; `fetch` reprints it) ---
[ -f "$HOME/.config/shell/greeting.sh" ] && . "$HOME/.config/shell/greeting.sh"'


# If ~/.bash_profile exists, bash reads it INSTEAD of ~/.profile, and Ubuntu's
# ~/.profile is what normally chains to ~/.bashrc. Without this, login shells
# (ssh, TTY) get none of the tooling. ~/.bashrc guards itself, so this is safe.
if [ -f "$HOME/.bash_profile" ] && ! grep -qE '(^|[^#])(\.|source)[[:space:]]+.*bashrc' "$HOME/.bash_profile"; then
  append_once "$HOME/.bash_profile" 'alter: chain to ~/.bashrc' \
'
# --- alter: chain to ~/.bashrc for login shells ---
[ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"'
else
  skip "~/.bash_profile already chains to ~/.bashrc (or does not exist)"
fi

hdr "git"
inc="$ALTER_ROOT/config/git/gitconfig.include"
if git config --global --get-all include.path 2>/dev/null | grep -qxF "$inc"; then
  skip "git include already present"
else
  run git config --global --add include.path "$inc"
  ok "git: include.path -> $inc"
fi
have delta || warn "delta not installed yet; git paging will fall back until it is"


hdr "bat theme (Catppuccin Mocha)"
link "$ALTER_ROOT/config/bat/themes/Catppuccin Mocha.tmTheme" \
     "$HOME/.config/bat/themes/Catppuccin Mocha.tmTheme"
if have batcat || have bat; then
  _bat=$(command -v batcat || command -v bat)
  if "$_bat" --list-themes 2>/dev/null | grep -qx "Catppuccin Mocha"; then
    skip "bat cache already has Catppuccin Mocha"
  else
    run "$_bat" cache --build >/dev/null 2>&1 && ok "bat cache rebuilt"
  fi
else
  skip "bat not installed; theme staged for later"
fi

hdr "Default terminal"
if have ghostty && [ -f /usr/share/applications/com.mitchellh.ghostty.desktop ]; then
  for f in "$HOME/.config/xdg-terminals.list" \
           "$HOME/.config/${XDG_CURRENT_DESKTOP%%:*}-xdg-terminals.list"; do
    if [ "$(cat "$f" 2>/dev/null)" = "com.mitchellh.ghostty.desktop" ]; then
      skip "$(basename "$f") already set"
    else
      run mkdir -p "$(dirname "$f")"
      [ "$DRY_RUN" = 1 ] || echo com.mitchellh.ghostty.desktop > "$f"
      ok "$(basename "$f") -> ghostty"
    fi
  done
  gset org.gnome.desktop.default-applications.terminal exec "'ghostty'"
  if have update-alternatives && [ "$(update-alternatives --query x-terminal-emulator 2>/dev/null | awk '/^Value:/{print $2}')" != /usr/bin/ghostty ]; then
    warn "x-terminal-emulator still points elsewhere; run:"
    say  "    sudo update-alternatives --set x-terminal-emulator /usr/bin/ghostty"
  fi
else
  skip "ghostty not installed; leaving default terminal alone"
fi
