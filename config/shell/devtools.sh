# ~/.config/shell/devtools.sh — sourced from ~/.bashrc
# Every block is guarded, so this file is safe to source before the tools exist.

# ---------- fd / bat / eza (Debian renames some binaries) ----------
command -v fdfind  >/dev/null && alias fd='fdfind'
command -v batcat  >/dev/null && { alias bat='batcat'; export BAT_THEME="Catppuccin Mocha"; }
if command -v eza >/dev/null; then
  alias ls='eza --group-directories-first'
  alias ll='eza -lah --group-directories-first --git --time-style=long-iso'
  alias la='eza -a  --group-directories-first'
  alias lt='eza --tree --level=2 --group-directories-first'
fi

# ---------- fzf: Ctrl+R history, Ctrl+T files, Alt+C cd ----------
# These are fzf's own defaults and don't collide with GNOME or readline.
if command -v fzf >/dev/null; then
  [ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && . /usr/share/doc/fzf/examples/key-bindings.bash
  [ -f /usr/share/bash-completion/completions/fzf ]    && . /usr/share/bash-completion/completions/fzf

  if command -v fdfind >/dev/null; then
    export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --follow --exclude .git --exclude .repo --exclude out'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fdfind --type d --hidden --follow --exclude .git --exclude .repo --exclude out'
  fi
  export FZF_DEFAULT_OPTS='
    --height 45% --layout=reverse --border=rounded --info=inline
    --color=bg+:#313244,spinner:#f5e0dc,hl:#f38ba8
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
    --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
    --color=border:#6c7086'
  command -v batcat >/dev/null && \
    export FZF_CTRL_T_OPTS="--preview 'batcat --style=numbers --color=always --line-range=:200 {} 2>/dev/null || ls -la {}'"
fi

# ---------- zoxide: 'z <partial>' jumps, 'zi' picks interactively ----------
command -v zoxide >/dev/null && eval "$(zoxide init bash)"

# ---------- git-delta ----------
# Enabled via ~/.gitconfig, nothing to do here.

# ---------- keys: print the hotkey reference ----------
# A function, not an alias: aliases are not expanded in non-interactive shells.
keys() {
  local f
  for f in "$HOME/alter/docs/hotkeys.txt" "$HOME/.config/alter/hotkeys.txt"; do
    [ -f "$f" ] || continue
    if [ -n "${1:-}" ]; then grep -i -- "$1" "$f"; else cat "$f"; fi
    return
  done
  echo "keys: hotkeys.txt not found (expected ~/alter/docs/hotkeys.txt)" >&2
  return 1
}
