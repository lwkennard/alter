# TODO — outstanding workflow implementation

Phases 0–2, 4 and 6 of the original plan are **done and verified** on Ubuntu 24.04 /
GNOME 46 / X11. This file tracks what is left, in the order it should be
adopted. Each item is self-contained enough to pick up cold.

Status key: `TODO` not started · `PARTIAL` some of it landed · `DONE` shipped
· `OPEN` a loose end from the original build.

---

## Done (for context)

| Phase | Item | Where it lives |
|---|---|---|
| 0 | Workspace + keybinding fixes, static workspaces, Nerd Font | `bootstrap/20-gnome.sh`, `bootstrap/10-fonts.sh` |
| 1 | rofi, fzf, zoxide, fd, bat, eza, delta | `bootstrap/00-packages.sh`, `config/shell/devtools.sh` |
| 2 | Ghostty as default terminal, GNOME-parity keymap | `config/ghostty/config`, `bootstrap/30-dotfiles.sh` |
| 4 | **PaperWM** scrollable tiling; Tiling Assistant disabled | `bootstrap/40-extensions.sh` |
| 5 | **Catppuccin Mocha everywhere** — terminal, rofi, fzf, bat, delta, desktop | `config/git/gitconfig.include`, `config/bat/themes/` |
| 6 | **Just Perfection**, **Clipboard Indicator** (`Super+V`) | `bootstrap/40-extensions.sh` |

---

## Phase 3 — Multiplexer  ·  `TODO`  ·  highest remaining value

**Problem.** Long builds outlive the terminal window that started them. Close
the window or lose the SSH connection and the build dies with it. This is the
single biggest remaining gap in the workflow.

**Pick one:**

| | tmux | Zellij |
|---|---|---|
| In Ubuntu repos | yes (3.4) | no — needs a `.deb`/cargo/binary |
| Keybindings | prefix-based, must be learned | on-screen hints, discoverable |
| Remote sessions | ubiquitous on servers | rarely preinstalled |

Recommendation: **tmux**, specifically because remote build servers already
have it — a Zellij habit doesn't transfer to a box you can't install on.

**Do:**
1. Add `tmux` to `APT_PKGS` in `bootstrap/00-packages.sh`.
2. Add `config/tmux/tmux.conf`; symlink it from `bootstrap/30-dotfiles.sh` to
   `~/.config/tmux/tmux.conf` (tmux 3.1+ reads that path).
3. Keep bindings conventional per the repo's guiding rule. Suggested minimum:
   `set -g mouse on`, a larger `history-limit`, `set -g base-index 1` so window
   numbers line up with the `Super+1..4` muscle memory, and
   `set -g default-terminal 'tmux-256color'`.
4. Leave the `C-b` prefix alone unless there is a concrete reason. `C-a`
   collides with readline's beginning-of-line, which is used constantly.

**Acceptance:** `tmux new -d -s t && tmux ls | grep -q '^t:'`, plus a binary
check in `bootstrap/verify.sh`.

**Interaction with Ghostty.** Ghostty already has splits and tabs. Use tmux for
*persistence* (detach/reattach, remote) and Ghostty for *layout*. Running both
as layout managers means two conflicting keymaps for the same job.

---

## Phase 4 — PaperWM  ·  `DONE`

Installed from extensions.gnome.org (v148, claims GNOME 45–50), enabled, and
configured in `bootstrap/40-extensions.sh`. Ubuntu's **Tiling Assistant was
disabled** — the two fight over tiling.

Keybinding division settled after a full 100-binding conflict scan:

| Owner | Keys |
|---|---|
| GNOME | `Super+1..4`, `Super+Shift+1..4` — numbered workspace jumps and moves; `Super+Alt+←/→` — previous/next workspace; `Super+Shift+←/→` — move window to previous/next workspace |
| PaperWM | `Super+Shift+Alt+arrows` — focus another monitor; `Super+Shift+Ctrl+arrows` — move window to another monitor; `Alt+Tab` and window navigation |
| Ghostty | `Ctrl+Shift+arrows` — split navigation; its stock `Ctrl+Alt+arrows` split bindings are explicitly unbound |

GNOME's `switch-to-workspace-left/right` and `move-to-workspace-left/right`
remain bound as above. Their extra stock aliases, including `Super+PgUp/PgDn`
and `Ctrl+Alt+←/→`, are removed. PaperWM's overlapping workspace bindings
and horizontal monitor-swap bindings are cleared to avoid collisions.

**Still to confirm in daily use:** whether `Super+1..4` behaves sensibly under
PaperWM's per-monitor workspace model. PaperWM uses GNOME workspaces
underneath, so it should, but this has not been exercised yet.

## Phase 5 — Prompt and theme consistency  ·  `PARTIAL`

**Done:** JetBrainsMono Nerd Font; Catppuccin Mocha in Ghostty, rofi and fzf.

**Outstanding:**

- **`starship` prompt** — `TODO`. Not in Ubuntu 24.04 repos; install via the
  upstream script or cargo. Add `config/starship.toml`, symlink it, and add
  `eval "$(starship init bash)"` to `config/shell/devtools.sh` behind the
  existing `command -v` guard. Value here is git branch + state visible at a
  glance in deep trees.
- **Palette split** — `DONE`. `config/bat/themes/Catppuccin Mocha.tmTheme` is
  carried in the repo, symlinked by `30-dotfiles.sh`, and `bat cache --build`
  runs automatically. `delta` uses the official `catppuccin/delta` colour block
  as a named feature. Verified by the exact RGB values delta emits.
- **`atuin`** — `TODO`, optional. Searchable, synced, statistical shell
  history. Strictly better than fzf's `Ctrl+R` for history specifically, but it
  is a daemon and a sync account — evaluate against IT policy before adopting.

---

## Phase 6 — GNOME extensions  ·  `DONE`

Both installed and configured in `bootstrap/40-extensions.sh`.

- **Just Perfection** — deliberately conservative: boots to desktop instead of
  the overview, faster animations, wrapping workspaces, no `Super Super` app
  grid. Nothing is hidden, so nothing looks broken.
- **Clipboard Indicator** — `Super+V` (the widely-known convention; nothing
  else claimed it), 50 entries, newest first, `strip-text` off so copied code
  keeps its whitespace.

The list stops here on purpose. Every extension is a thing that can break on
the next GNOME upgrade.

---

## Open loose ends

| # | Item | Notes |
|---|---|---|
| 1 | **`Alt+C` (fuzzy cd) never verified end-to-end** | The widget `__fzf_cd__` exists and `key-bindings.bash` binds `\ec` unconditionally, but no harness in this build can drive a real readline session to prove the keystroke works. Confirm manually in a real terminal; if it fails, suspect a terminal-level `Alt` handling setting rather than the shell config. |
| 2 | **Non-Ubuntu / non-GNOME paths untested** | `is_debianish`, `is_gnome` and `gnome_ver` branches were written to degrade gracefully but have only ever run on Ubuntu 24.04 + GNOME 46. First run on a different box will likely need fixes. |
| 3 | **Git identity remains machine-specific** | `origin` is configured; `gitconfig.include` deliberately contains no `user.name`/`user.email`. Confirm the author for each machine with `git config user.name` and `git config user.email` before committing. |
| 4 | **Ghostty logs a GTK theme warning** | `Theme parser error: style.css:140:17-19: Unexpected data at end of hsl() argument` — that is Yaru's CSS against GTK 4.14, not this config. Cosmetic; ignore unless it starts causing render issues. |
| 5 | **Ghostty came from a third-party PPA** | `ppa:mkasberg/ghostty-ubuntu`. It lands in official Ubuntu repos at 26.04 — drop the PPA on upgrade. `ALTER_SKIP_GHOSTTY=1` skips it if IT policy objects. |
| 6 | **Old kitty fallback is gone on this machine** | `dpkg -l kitty` finds no package, and GNOME's terminal binding is `Ctrl+Alt+T`. On another machine, check both before removing a fallback terminal. |
| 7 | **PaperWM under a GNOME upgrade** | Extensions are the most fragile part of this setup. On the next Ubuntu LTS, check PaperWM supports the new Shell version *before* upgrading, or you get a session with no window management. |
| 8 | **Wayland session not evaluated** | Better multi-monitor and HiDPI handling, and PaperWM gains touchpad gestures. Blocker: **rofi's window mode is X11-only**, so `Super+Space` would need replacing (`fuzzel`, or a GNOME extension) before switching. |
| 9 | **fastfetch comes from a third-party PPA** | `ppa:zhangsongcui3371/fastfetch`. Ubuntu carries fastfetch itself from 24.10, so drop the PPA on the next release upgrade — `00-packages.sh` already prefers a repo candidate when one exists. `ALTER_SKIP_FASTFETCH=1` skips it; the banner degrades rather than disappears. |
| 10 | **The wallpaper picture itself is not in the repo** | `20-gnome.sh` sets `picture-options=spanned` (one image sliced across all monitors) but never `picture-uri` — the current picture lives at `~/.local/share/backgrounds/`, which GNOME Settings writes and nothing tracks. A fresh machine therefore spans Ubuntu's *default* wallpaper, which is sized for one screen and gets upscaled across the combined desktop (5120x1600 here). To fix: commit a picture at least as wide as the widest desktop you use under `config/`, symlink it in `30-dotfiles.sh`, and `gset` `picture-uri` and `picture-uri-dark` at it. Confirm with `gsettings get org.gnome.desktop.background picture-uri` and by eye — see the README gotcha on why a CLI screenshot cannot check this. |
| 11 | **The PaperWM background patch is a local source edit** | `bootstrap/paperwm-picture-options.py` edits `tiling.js` inside `~/.local/share/gnome-shell/extensions/paperwm@paperwm.github.com` so PaperWM honours `picture-options` instead of its hardcoded `BackgroundStyle.ZOOM`. Pinned to PaperWM v148 / 50.0.1. **A PaperWM update overwrites `tiling.js` and silently reverts it** — the wallpaper goes back to one copy per monitor. `./install.sh extensions` re-applies it and `verify.sh` warns when it is missing, so the recovery is one command; the patcher refuses to touch a `tiling.js` whose anchors moved, so an upstream restructure fails loudly rather than corrupting the extension. Worth raising upstream: `background.js` already reads the key in `getBackground()`, `tiling.js` just bypasses it — a genuine one-line upstream fix. |
| 12 | **Real uninstall sequence not yet exercised** | Only `DRY_RUN=1 ./uninstall.sh` has run. The script disables extensions, waits up to 10 seconds for PaperWM to leave `ACTIVE`, then resets GNOME keys, unlinks configs, removes shell hooks and the Git include, and removes its `xdg-terminals.list` entries. Confirm on a disposable machine or VM: run `./uninstall.sh`, then `./bootstrap/verify.sh` should fail its alter-specific checks and `gsettings get` should show GNOME defaults. |

---

## Conventions for whoever picks this up

Read the "Working on this repo" section of [`../README.md`](../README.md)
first. In short: every stage idempotent, every change reversible, `--dry-run`
stays honest, detect rather than assume, and add a `verify.sh` check for
anything new. The "Gotchas found the hard way" list there will save you the
`pipefail`/SIGPIPE afternoon.
