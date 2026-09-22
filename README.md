# ALTER

Tools for my personal workflow, portablized.
Clone it onto a new machine, run one script, log out and back in.

Built and verified on **Ubuntu 24.04 / GNOME 46 / X11**.

```bash
git clone <repo-url> ~/alter
cd ~/alter
./install.sh --dry-run   # see exactly what would change
./install.sh             # do it
```

---




/**** AI SLOP CONTAINMENT ZONE ****/




## What you get, and why

| Tool | Solves | Daily use |
|---|---|---|
| **[rofi](https://github.com/davatorium/rofi)** | GNOME has no cross-workspace window search | `Super+Space`, type part of a window title, Enter |
| **[Ghostty](https://ghostty.org)** | GNOME Terminal has no splits; kitty isn't GTK-native | Default terminal. GPU-rendered, GTK4/libadwaita |
| **[fzf](https://github.com/junegunn/fzf)** | `Ctrl+R` history search is near-useless by default | `Ctrl+R` history, `Ctrl+T` files, `Alt+C` cd |
| **[zoxide](https://github.com/ajeetdsouza/zoxide)** | `cd`-ing through deep trees | `z proj` jumps anywhere you have been; `zi` to pick |
| **[fd](https://github.com/sharkdp/fd)** | `find` syntax | `fd pattern`. Backs the fzf pickers |
| **[bat](https://github.com/sharkdp/bat)** | `cat` has no highlighting | `bat file`. Also the fzf preview pane |
| **[eza](https://github.com/eza-community/eza)** | `ls` | `ll` / `la` / `lt` (tree) |
| **[delta](https://github.com/dandavison/delta)** | git diffs are hard to scan | Automatic for `git diff`/`show`/`log -p` |
| **[starship](https://starship.rs)** | the stock prompt shows nothing about git or the toolchain | The prompt: path, branch, dirty/ahead state, rebase in progress, slow-command time; `user@host` only over ssh |
| **JetBrainsMono Nerd Font** | icons render as tofu without it | Terminal font; needed by most modern prompts |
| **[fastfetch](https://github.com/fastfetch-cli/fastfetch)** | a new terminal tells you nothing about the machine it is on | The banner every terminal opens with. `fetch` reprints it |
| **[PaperWM](https://extensions.gnome.org/extension/6099/paperwm/)** | manual window placement wastes a wide screen | Scrollable tiling, per-monitor workspaces. `Super+←/→` scrolls the strip |
| **Just Perfection** | GNOME's shell chrome isn't tunable | Boots to desktop, faster animations, wrapping workspaces |
| **Clipboard Indicator** | copying between editor/terminal/browser loses history | `Super+V`, last 50 copies |

Everything runs one palette: **Catppuccin Mocha** in Ghostty, rofi, fzf, bat,
git-delta and the starship prompt, with `Yaru-purple-dark` on the desktop as
the closest native GTK match.

starship is the one tool that does not come from apt: Ubuntu 24.04 has no
package and there is no PPA, so `bootstrap/05-starship.sh` downloads the
static release tarball from GitHub, checks it against the published sha256
and installs the single binary to `~/.local/bin` — no root and no `curl | sh`.
`ALTER_SKIP_STARSHIP=1` keeps the stock bash prompt; `ALTER_STARSHIP_VERSION`
pins a release. The prompt layout is `config/starship/starship.toml`, linked
to `~/.config/starship.toml`, so an edit there shows in the next terminal.

The wallpaper is set to `spanned`, so one picture is sliced across all
monitors rather than copied onto each. That takes two changes, not one:
the gsettings key in `20-gnome.sh`, **and** a patch to PaperWM in
`40-extensions.sh`, because PaperWM draws the desktop itself and ignores the
key. The picture itself stays yours — this repo sets the layout, never
`picture-uri`.

Ghostty never posts to GNOME's notification tray: OSC 9/777 desktop
notifications, the bell's "Ghostty is ready" attention request and
command-finished notifications are all off in `config/ghostty/config`. A bell
still puts 🔔 in the tab title, and the in-window "copied" toast still shows.

**Deliberately not included:** a multiplexer (tmux/zellij) — high value, but
it is the one remaining thing that changes muscle memory. See [Roadmap](#roadmap).

---

## Keybindings

The guiding rule: **stay conventional.** Nothing here contradicts a GNOME or
GNOME Terminal default unless it had to, and every exception is noted.

### Desktop

| Key | Action |
|---|---|
| `Super+1..4` | Go to workspace N (fixed — always the same workspace; was dock favourites) |
| `Super+Shift+1..4` | Move focused window to workspace N |
| `Super+Alt+←/→` | Previous / next workspace |
| `Super+Shift+←/→` | Move focused window to previous / next workspace (stock move-to-monitor unbound) |
| `Super+Shift+Alt+arrows` | Focus the other monitor (PaperWM) |
| `Super+Ctrl+Shift+arrows` | Move window to another monitor (PaperWM) |
| `Super+Alt+↑/↓` | Swap the monitors above / below (PaperWM) |
| `Super+V` | Clipboard history, last 50 copies |
| `Super+Space` | rofi window switcher (defaults to `Super+W` with multiple input sources; overridable with `ALTER_ROFI_KEY`) |
| `Ctrl+Super+1..9` | Dock favourite N (unchanged) |
| `Ctrl+Alt+T` | New terminal |

Three deliberate deviations from Ubuntu's defaults:

1. **`Super+N` was taken from the dock.** It launched dock favourites; it now
   switches workspaces, which is the cross-desktop convention. `Ctrl+Super+N`
   still launches favourites.
2. **`Super+Space` was taken from input-source switching.** Only safe with a
   single keyboard layout — `20-gnome.sh` checks, and falls back to `Super+W`
   if you have more than one.
3. **Workspace prev/next is trimmed to one binding.** GNOME ships *three*
   aliases per direction — `switch-to-workspace-left` defaults to
   `['<Super>Page_Up','<Super><Alt>Left','<Control><Alt>Left']`. Only
   `Super+Alt+←/→` is kept. `Super+PgUp/PgDn` and `Ctrl+Alt+←/→` are
   deliberately left **free** for you to bind to whatever you like.
   `switch-to-workspace-up/down` are emptied too: GNOME 40+ lays workspaces out
   in a horizontal strip, so there is nothing above or below to reach.

Check the gschema XML before assuming a key is yours to take — a GNOME
"default" is often a list, and dropping one entry is usually enough.

### Ghostty

Ghostty's stock Linux keymap largely matches GNOME Terminal, so
`config/ghostty/config` changes only a few keys. These are **defaults**:

| Key | Action |
|---|---|
| `Ctrl+Shift+T` / `N` | New tab / window |
| `Ctrl+Shift+W` / `Q` | Close tab / quit |
| `Ctrl+Shift+C` / `V` | Copy / paste |
| `Ctrl+PgUp` / `PgDn` | Previous / next tab |
| `Alt+1..8` / `Alt+9` | Jump to tab N / last tab |
| `Ctrl+Plus` / `-` / `0` | Font bigger / smaller / reset |
| `Ctrl+Shift+O` / `E` | Split right / down |
| `Ctrl+Shift+Enter` | Zoom split |
| `Ctrl+Shift+P` | Command palette |

Two binding families are set here:

| Key | Action | Why |
|---|---|---|
| `Ctrl+Shift+PgUp/PgDn` | Reorder tab | Replaces Ghostty's jump-to-prompt default |
| `Ctrl+Shift+arrows` | Move between splits | Replaces Ghostty's `Ctrl+Alt+arrows` default, which collides with GNOME's workspace switch |

`Ctrl+Shift+←/→` were Ghostty's aliases for previous/next tab. `Ctrl+PgUp/PgDn`,
`Ctrl+Tab`/`Ctrl+Shift+Tab` and `Alt+1..9` all still switch tabs, so nothing is
lost.

Ghostty's stock `Ctrl+Alt+arrows` split bindings are explicitly unbound in
this config, leaving those keys free for terminal programs.

Note that `Ctrl+Shift+arrow` is *not* a free key inside the terminal — unbound,
it sends `\e[1;6A..D` to the running program (just as `Ctrl+Alt+arrow` sends
`\e[1;7A..D`). Binding it in Ghostty means Ghostty consumes it and the program
never sees it. Nothing in this setup wants it, but a TUI that does would lose
it.

**If `Ctrl+Shift+arrow` prints a bare `A`/`B`/`C`/`D` at your prompt**, that is
the tail of that escape sequence leaking through: Ghostty is running with an
older config. Ghostty does not hot-reload — press `Ctrl+Shift+,`
(`reload_config`), or quit and relaunch.

### Shell

`Ctrl+R` history · `Ctrl+T` file picker · `Alt+C` fuzzy cd — all stock fzf.

### Not in `keys`

`keys` prints `docs/hotkeys.txt`, which is capped at one screen (30 lines) and
holds only the bindings you cannot guess. These work too, but did not make the
cut:

| Key | Action |
|---|---|
| `Super+,` / `Super+.` | Previous / next window along the strip (PaperWM) |
| `Super+Home` / `Super+End` | First / last window in the strip (PaperWM) |
| `` Super+` `` | Back to the previous workspace (PaperWM) |
| `Super+T` | Take window: carry it with you to another position (PaperWM) |
| `Super+C` | Centre the window horizontally (PaperWM) |
| `Super+Alt+↑/↓` | Swap the monitors above / below (PaperWM) |
| `Super+N` | New window, alias of `Super+Return` (PaperWM) |
| `Ctrl+Super+1..9` | Dock favourite N (stock GNOME) |
| `Super` / `Super+A` | Overview / app grid (stock GNOME) |
| `Alt+F4` / `Super+H` | Close / minimise window (stock GNOME) |
| `Ctrl+Shift+N` / `Q` | New Ghostty window / quit (stock) |
| `Ctrl+Plus` / `-` / `0` | Font bigger / smaller / reset (stock Ghostty) |
| `Ctrl+Shift+P` / `Ctrl+Shift+,` | Ghostty command palette / reload config (stock) |
| in rofi: `Ctrl+N` / `Ctrl+P` | Next / previous match (`Alt+Tab` / `Alt+Shift+Tab` too); `Ctrl+Enter` accepts typed text as-is |

---

## The terminal greeting

Every new terminal opens with a [fastfetch](https://github.com/fastfetch-cli/fastfetch)
banner — the machine's facts beside a piece of ASCII art:

```
       .,ooa@@@@aoo,.        user@computer
     ,a@@@@@@@@@@@@@@a,      os   <the os>
    #@@@@@@@@@@@@@@@@@@#     ker  <the ker>
   @@@@@@@@@@@@@@@@@@@@@@    up   <uptime>
  @@@@"''"*@@@@@@*"''"@@@@   pkg  <pkgs>
 #@@/      \@@@@/      \@@#  sh   <the sh>
 @@@,,,,,,,,@@@@,,,,,,,,@@@  term <the term>
 #@@@@@@@@@@@@@@@@@@@@@@@@#  wm   <the wm>
  @@@@@@@@@@@@@@@@@@@@@@@@   cpu  <the cpu>
   @@@@@@@@@@@@@@@@@@@@@@    gpu  <the gpu>
    #@@@@@@@@@@@@@@@@@@#     mem  <the mem>
     '*@@@@@@@@@@@@@@*'      disk <the disk>
       `'""#@@@@#""'`        ● ● ● ● ● ● ● ●
```

The art is **Vergil** — the Superintendent's happy face from Halo 3: ODST —
converted from [`config/fastfetch/vrgl-happy.png`](config/fastfetch/vrgl-happy.png)
by [`bin/img2logo`](bin/img2logo). Only the green face is drawn; the white ring
and the two eyes are **negative space**, left to the terminal background, which
is why the eyes are holes rather than pale shapes. 26 columns by 13 rows —
exactly the height of the facts column, so both sides start and finish on the
same line.

The whole banner is **76 columns**, which is deliberate: a default Ghostty
window here is 77, and the `cpu` line is the longest thing in the panel. At the
roomier padding it started with, the banner came to 79 and that one line
wrapped, which does not look like a long line — it looks like the layout is
broken. If you add a wider module, check the total again:
`fastfetch | sed 's/\x1b\[[0-9;]*m//g' | awk '{print length}' | sort -rn | head -1`.

Edges are where a converter earns its keep. Density alone turns a circle into a
staircase, so each partial cell is judged on *where* its ink sits as well as how
much there is: ink pooled low takes a character that hangs low (`.` `,`), ink
riding high takes `'` or `"`, a vertical edge takes a bracket and a shoulder
takes a slash. That is what the hand-drawn terminal art of the era did, and it
is the difference between a round disc and a blocky one at 13 rows.

**The `wm` line is detected, not declared.** PaperWM is a GNOME Shell
extension rather than a window manager, so fastfetch's own `wm` module only
ever says `Mutter (X11)` — which undersells a session PaperWM is really
driving. `config.jsonc` replaces that module with a one-line shell command that
appends `w/ PaperWM` only when `org.gnome.shell enabled-extensions` actually
lists it. Turn the extension off in Extension Manager and the next terminal
says plain `Mutter (X11)`; open the session over ssh with no desktop at all and
it says `none`. The check is one `gsettings` read, about 4ms. It replaces the
`wm` module rather than adding a line, because a fourteenth row would leave the
art a row short of the panel.

**Converting your own picture.** [`bin/img2logo`](bin/img2logo):

```bash
bin/img2logo ~/Pictures/whatever.png --rows 13 --style ascii > config/fastfetch/logo.txt
```

| Flag | Does |
|---|---|
| `--style ascii` | fill one colour with ordinary characters, everything else background |
| `--style blocks` | half-block glyphs, every colour drawn, one colour token per cell |
| `--rows N` | height in character rows; width defaults to `2N`, which keeps a square subject square |
| `--cols N` | override the output width in character columns |
| `--colors N` | quantise to the N most common source colours (default 3) |
| `--fill N` | which colour `ascii` draws: 0 is the most common one that is not background |
| `--ramp " .:-=+*oa#@"` | the density characters, empty to solid |
| `--ink N` | minimum non-background share to draw a block cell (default 0.40) |
| `--no-mirror` | keep the left and right halves as the image has them |

It quantises to the few most common colours and treats whatever touches the
border as background — flood filled, so a plate *and* the page behind its
rounded corners both fall away while a ring inside the picture survives — then
crops to the largest remaining blob. The colour legend goes to stderr: paste it
into `"color"` in `config.jsonc`. Flat icons convert well; photographs come out
as mud. Needs `python3-pil`.

**The art is yours.** It is a plain text file,
[`config/fastfetch/logo.txt`](config/fastfetch/logo.txt), symlinked to
`~/.config/fastfetch/logo.txt`. Edit it and the next terminal shows the change
— nothing is generated, cached or compiled. Inside it:

- `$1` … `$9` are colours you assign in `config.jsonc`; this art uses one, `$1`
  for the green, taken from the source PNG. `$$` is a literal `$`. If your art
  contains its own escape sequences, switch `"type": "file"` to `"file-raw"` so
  fastfetch passes it through untouched.
- Any width and height works — the two columns are independent, and whichever
  is shorter just ends early. To match heights the way the shipped art does,
  count the facts column: one row per module, plus one for the title and one
  for each `"separator"` or `"break"`. The current list is 13 modules and
  nothing else, so: 13 rows. `verify.sh` checks the two against each other and
  warns when they drift apart.
- **The art file ends without a trailing newline, deliberately.** fastfetch
  draws that newline as one more, empty, logo row — the art then measures one
  row taller than the panel and `verify.sh` says so. `wc -l` reports 12 for the
  13-row file for the same reason; `grep -c ''` reports 13. The blank line
  between the banner and the first prompt comes from `fetch` in
  `config/shell/greeting.sh`, which is the one place it costs nothing.
- Keep it under ~30 columns if you care about 80-column terminals: the longest
  fact line (`os`) runs to about 45.
- Sources: `fastfetch --list-logos` ships hundreds of distro logos
  (`fetch --logo arch`), and figlet/toilet or any ASCII-art generator will make
  a wordmark.

**What it prints** is [`config/fastfetch/config.jsonc`](config/fastfetch/config.jsonc)
— an ordered list of modules. `fastfetch --list-modules` shows every available
one, `fastfetch --help <module>` its options.

| Want | Do |
|---|---|
| Print it again | `fetch` (takes fastfetch flags when installed: `fetch --logo none`) |
| Try someone else's art | `fetch --logo-type file --logo /path/to/art.txt` |
| Use a picture you have | `bin/img2logo pic.png --rows 13 --style ascii > config/fastfetch/logo.txt` |
| Stop it appearing | `export ALTER_NO_GREETING=1` in `~/.bashrc` |
| Keep it, but faster | Drop `gpu`/`disk` from the module list — they are the slow ones |

It prints **once per terminal**: `greeting.sh` exports `ALTER_GREETED` holding
the tty it printed on, so a `bash` started inside this window shares that tty
and stays quiet, while a new window is a new pts and greets. `fetch` ignores
the marker and always prints.

If fastfetch is not installed — a non-Debian machine, or
`ALTER_SKIP_FASTFETCH=1` — the banner still appears, drawn by a fallback in
`config/shell/greeting.sh` that needs only standard shell tools and shows the
same art with a shorter set of facts.

---

## Layout

```
alter/
├── install.sh              entry point; runs stages in order
├── uninstall.sh            resets GNOME keys, unlinks configs, unhooks ~/.bashrc
├── bootstrap/
│   ├── lib.sh              logging, symlink+backup, gset, distro detection
│   ├── 00-packages.sh      apt packages + Ghostty (PPA on Ubuntu < 26.04)
│   ├── 05-starship.sh      starship prompt binary from GitHub, sha256-checked, user-local
│   ├── 10-fonts.sh         JetBrainsMono Nerd Font, user-local, no root
│   ├── 20-gnome.sh         workspaces, keybindings, rofi launcher
│   ├── 30-dotfiles.sh      symlinks, .bashrc hook, git include, default term
│   ├── 40-extensions.sh    PaperWM, Just Perfection, Clipboard Indicator
│   ├── paperwm-picture-options.py  patches PaperWM wallpaper rendering
│   └── verify.sh           post-install checks; exits non-zero on failure
├── config/                 dotfiles and source assets; active configs linked into ~
│   ├── ghostty/config
│   ├── rofi/{config.rasi,themes/catppuccin-mocha.rasi}
│   ├── bat/themes/         Catppuccin Mocha tmTheme for bat + delta
│   ├── shell/devtools.sh   fzf/zoxide/fd/bat/eza/starship wiring, every block guarded
│   ├── shell/greeting.sh   new-terminal banner + `fetch`, with a fallback
│   ├── starship/starship.toml  the prompt: two lines, Catppuccin Mocha palette
│   ├── fastfetch/logo.txt  the ASCII art — edit this, no build step
│   ├── fastfetch/config.jsonc  what the banner prints, and in what order
│   ├── fastfetch/vrgl-happy.png  the picture logo.txt was converted from
│   └── git/gitconfig.include  delta pager and colour settings
├── bin/zenity-askpass      GUI sudo prompt for non-TTY contexts
├── bin/img2logo            image -> ASCII/block logo art (needs python3-pil)
├── bin/merge-latest        land the newest worktree branch on main and push it
├── docs/
│   ├── hotkeys.txt         one-screen hotkey reference (`keys`); shape enforced by verify.sh
│   └── TODO.md             outstanding work, acceptance criteria, loose ends
├── local/README.md         machine-specific env.sh is sourced when readable
├── .gitignore              local files, backups, and editor junk
├── CLAUDE.md               repo rules: one-screen `keys` reference, reproducible setup
└── README.md               setup, usage, and conventions
```

Active dotfiles under `config/` are **symlinked**, not copied — edit them in
place and commit. The source PNG and Git include are read from the repo.

---

## Working on this repo

Conventions to follow if you extend it (human or agent):

- **Everything is idempotent.** Re-running is a no-op. Use `gset` (only writes
  when the value differs) and `link` (skips if already correct).
- **Everything is reversible.** `link` backs up whatever it replaces into
  `~/.local/share/alter-backup/<timestamp>/`.
- **`--dry-run` must stay honest.** Route side effects through `run`. Use
  `runq` when a command's own output should be hidden: `run cmd >/dev/null`
  also swallows the `[dry-run]` line.
- **Detect, don't assume.** `is_gnome`, `is_debianish`, `have`, `gnome_ver`.
  Warn and skip rather than failing the whole run.
- **New stage?** Drop `NN-name.sh` in `bootstrap/`, add it to `STAGES` and
  `MOD` in `install.sh`, and add a check to `verify.sh`.
- **Changed a keybinding?** Update `docs/hotkeys.txt` (what `keys` prints) and
  the keybinding sections above, in the same commit. Added, removed or
  modified — a stale printout is an incomplete change. `hotkeys.txt` has a
  hard shape: at most 30 lines of 72 columns, keystrokes and actions only, no
  history or rationale (that lives here). `verify.sh` fails on violations.
  Full rule in [`CLAUDE.md`](CLAUDE.md).
- **Changed anything on the machine?** Put it in a bootstrap stage, check it in
  `verify.sh`, revert it in `uninstall.sh` — and write what went wrong into
  "Gotchas" below or `docs/TODO.md`. A hand-made change survives nothing; an
  unrecorded problem gets solved again on the next machine. Full rule in
  [`CLAUDE.md`](CLAUDE.md).
- **Landing a worktree branch?** `bin/merge-latest` merges the worktree branch
  with the newest commit into `main` and pushes it. Preview with `--dry-run`;
  name a branch to override the pick; `--ff` fast-forwards instead of making
  a merge commit; `--clean` removes the worktree and deletes the branch
  locally and on `origin` afterwards. It refuses to touch anything when either
  checkout is dirty, when `main` has diverged from `origin`, or when the merge
  conflicts (the merge is aborted). It never force-pushes.

### Gotchas found the hard way

- **An extension can be installed, listed in `enabled-extensions`, and still
  never run.** Every extension looked configured — `gnome-extensions info`
  said `Enabled: No`, `State: INITIALIZED`, and PaperWM had never tiled a
  single window. The cause is `org.gnome.shell disable-user-extensions`, whose
  own gschema says it *"takes precedence over the enabled-extensions setting"*:
  one boolean silently kills everything under
  `~/.local/share/gnome-shell/extensions`. The tell is that **only user
  extensions die** — the four in `/usr/share` (ding, ubuntu-dock,
  appindicators, tiling-assistant) stayed `ACTIVE` while all three of ours sat
  at `INITIALIZED`. GNOME Settings' Extensions toggle and gnome-shell's
  crash-recovery both set it, so a machine acquires it without anyone choosing
  it. `40-extensions.sh` now sets it false before enabling anything, and
  flipping it loads the extensions live — no shell restart needed.

- **Ubuntu's own extensions are enabled by default, so removing them from
  `enabled-extensions` does nothing.** `40-extensions.sh` "disabled"
  tiling-assistant by filtering it out of that list, and `verify.sh` confirmed
  success by grepping the same list — while `gnome-extensions info` said
  `Enabled: Yes`, `State: ACTIVE`. Extensions shipped in `/usr/share` never
  appear in `enabled-extensions` at all; the only key that turns one off is
  `disabled-extensions`, which is what `gnome-extensions disable` writes. A
  check that greps the enabled list can therefore only ever pass. Ubuntu's
  snap-assist was fighting PaperWM for every window.

- **A verify check that prints state instead of asserting it is not a check.**
  `verify.sh` printed `✓ paperwm@paperwm.github.com (INITIALIZED)` and exited 0
  for as long as PaperWM had never loaded — the state was interpolated into
  the success line rather than compared against `ACTIVE`. Both bugs above hid
  behind a green run. Assert the value you require; never echo whatever you
  found next to a tick.

- **fastfetch drops a module it does not recognise in silence.** A JSONC
  *syntax* error exits 221 and says so; a module name that does not exist —
  `"memmory"`, or one renamed between releases — produces **no error, no line,
  and exit 0**. Mistype the wrong one and the banner comes back empty while
  every command still "succeeds". `verify.sh` therefore counts the output lines
  (`--pipe --logo none | grep -c .`) instead of trusting the exit code, the
  same way it has to for rofi themes. Ground truth: `fastfetch --list-modules`.
- **A "print once per terminal" guard is neither `$SHLVL` nor a flag.** Both
  fail, in opposite directions. `$SHLVL` is an absolute depth, so
  `[ "$SHLVL" -le 1 ]` only identifies the outermost shell when the terminal was
  launched straight from the desktop; anything that runs a shell in between —
  `script`, a test harness, an agent, `ssh host bash` — makes every real
  terminal `SHLVL=2` or more and the banner silently never appears. Observed:
  the greeting worked by hand and printed nothing under
  `script -qec "bash -lic true"`. Replacing it with an exported flag then broke
  the other way — a window launched from a shell that had already greeted
  inherited the flag and came up blank. Observed: `ghostty -e …` from an agent
  shell carrying `ALTER_GREETED=1` opened a real window with no banner.
  `greeting.sh` stores **the tty** instead, which is what "this terminal"
  actually means: a new window is a new pts and greets, a shell inside this one
  shares the pts and does not. Note `tty` reports the terminal of *stdin*, so
  test it the way the shell will see it, not through a pipe.
- **fastfetch names the terminal by walking the process tree.** Run under
  anything that is not your terminal — a wrapper, an agent, a CI shell — and
  `term` reports that wrapper's process name (here: `2.1.278`) rather than
  `ghostty 1.3.1`. The line is right in a real window; do not "fix" it by
  pinning a terminal name. Confirm with
  `ghostty -e bash -c "script -qc 'bash -lic true' /tmp/s.txt"` and read the file.

- **Do not add `set -o pipefail` to `lib.sh`.** `fc-list | grep -q` makes
  `grep` exit on first match, which SIGPIPEs `fc-list` (exit 141); `pipefail`
  then reports the whole pipeline as failed even though the match succeeded.
  This silently broke the font detection. Verified via `PIPESTATUS: 141 0`.
  Prefer `grep -F … >/dev/null` (consumes all input) in pipelines.
- **Readline bindings need a real PTY.** `bind -X` returns nothing under a
  plain `bash -c`. `verify.sh` wraps it in `script -qec …` to allocate one.
- **`Ctrl+Alt+arrows` is grabbed by the WM**, so apps never see it until GNOME
  releases it. Check for desktop-level grabs before blaming an app's config.
- **Ghostty theme names changed in 1.2.0** — `Catppuccin Mocha`, not
  `catppuccin-mocha`. Validate with `ghostty +validate-config`.
- **Ghostty does not hot-reload its config.** `ghostty +show-config` and
  `+list-keybinds` read the *file*, so they happily confirm a binding that no
  running window has. The tell is a bare `A`/`B`/`C`/`D` appearing at the
  prompt: an unbound `Ctrl+Shift+arrow` passes `\e[1;6A..D` through to bash,
  which eats the `\e[1;6` and leaves the final letter. Press `Ctrl+Shift+,`
  (`reload_config`) or restart. Check `ps -eo pid,lstart,cmd | grep ghostty`
  against the file mtime before trusting either command's output.
- **rofi reports theme errors only in the launcher overlay, and still exits
  0.** A `highlight:` value must be a *literal* colour: `highlight: bold
  @accent` fails to parse even though `text-color: @accent` two lines up is
  fine, and one bad property drops the entire theme. Both `rofi -dump-config`
  and `rofi -dump-theme` exited 0 while `Super+Space` was showing `syntax
  error, unexpected Reference, expecting "property close (';')"`. The only
  signal the CLI gives is that `-dump-theme` prints *nothing* instead of ~2KB,
  so `verify.sh` tests its output, never its exit code. To read the message
  itself: launch rofi and screenshot it — it is not on stderr.
- **`~/.bash_profile` shadows `~/.profile`.** If `~/.bash_profile` exists, bash
  reads it *instead of* `~/.profile` for login shells — and `~/.profile` is
  what normally chains to `~/.bashrc`. The symptom is that ssh/TTY logins get
  none of your PATH, aliases or tooling while terminal windows work fine.
  `30-dotfiles.sh` adds the chain when it is missing.
- **Test shells in the right mode.** `bash -c` is non-interactive (`.bashrc`
  bails early), `bash -lc` is login-but-non-interactive (also bails), and
  aliases are not expanded in either. Only `bash -lic` under a real PTY
  reproduces what `ssh host` gives you. Prefer functions over aliases.
- **gsettings doubles round-trip lossily.** Setting `0.18` reads back as
  `0.17999999999999999`, and `0.6` as `0.59999999999999998`, so a string
  comparison never matches and the key is rewritten on every run. The symptom
  is a `--dry-run` that always shows pending writes for float keys even though
  nothing changed. `gset` and `xset` compare numerically when both sides parse
  as numbers.
- **An extension can silently own a key you bound.** PaperWM ships 100
  keybindings; four collided with this repo's. Dump them
  (`gsettings --schemadir <ext>/schemas list-recursively <schema>.keybindings`)
  and diff against your own *before* enabling, not after something stops
  working.
- **PaperWM puts back GNOME keys it once displaced.** When PaperWM claims a
  chord GNOME also binds, it empties the GNOME key and saves the old value in
  its own `restore-keybinds` key, then replays that list on every shell start
  and on every change to one of its keybindings. So moving PaperWM's
  `switch-monitor-*` off `Super+Shift+arrows` would have brought stock
  `move-to-monitor-left` (`['<Super><Shift>Left']`) straight back on top of the
  `move-to-workspace-left` bound there. `restore-keybinds` held all four
  `move-to-monitor-*` entries; `40-extensions.sh` drops them before rebinding,
  and `verify.sh` fails if they reappear. PaperWM also *watches* GNOME's
  keybinding schemas: setting `move-to-workspace-left` while PaperWM still held
  `Super+Shift+Left` got it emptied and queued in the same list, and PaperWM's
  replay writes back a stale copy (`restore-keybinds` still listed
  `move-to-workspace-left` after the key was live again). Left there, disabling
  PaperWM re-applies it after `uninstall.sh` resets it, so those entries are
  dropped too. Because the rebind itself makes PaperWM rewrite the list,
  `40-extensions.sh` scrubs it a second time after rebinding, so one run
  reaches the verified state (that second pass has only been exercised under
  `--dry-run`). `uninstall.sh` therefore disables the extensions first and
  waits for PaperWM's `disable()` to finish before resetting GNOME keys;
  otherwise that replay could overwrite the reset.
- **GNOME Terminal can reclaim the default terminal after installation.**
  The default changed back and `verify.sh` did not catch it. Starting
  `gnome-terminal-server` rewrites `~/.config/xdg-terminals.list`,
  `ubuntu-xdg-terminals.list`, and `GNOME-xdg-terminals.list`: its binary
  contains the format string `%s-xdg-terminals.list`, and all three files
  changed within 110 ms at 10:42:43, with `org.gnome.Terminal.desktop` first
  and Ghostty second. `xdg-terminal-exec` reads the first entry. The dotfiles
  stage now checks that line, and `verify.sh` warns to run
  `./install.sh dotfiles`. Launching GNOME Terminal can make it recur.
- **Check defaults before overriding them.** `ghostty +list-keybinds --default`
  revealed that ~20 of the bindings originally written here were redundant, and
  three settings (`scrollback-limit`, `copy-on-select`, split direction) were
  *worse* than stock.
- **PaperWM draws the desktop itself, so `picture-options` does nothing.**
  The symptom is total: `spanned`, `centered` and `stretched` all render
  identically — one zoomed copy per monitor — whether set with `gsettings`,
  GNOME Settings or GNOME Tweaks. The cause is that PaperWM gives every space
  its own `Meta.BackgroundActor` *per monitor* and `tiling.js` passes a
  hardcoded style:

  ```js
  this.metaBackground = new Background.Background({
      monitorIndex: this.monitor.index,
      style: GDesktopEnums.BackgroundStyle.ZOOM,   // picture-options never read
  });
  ```

  Its own `background.js` already knows how to read the key
  (`getBackground()` calls `this._settings.get_enum('picture-options')`) --
  `tiling.js` simply bypasses that path. `tiling.js` also watches
  `changed::picture-uri` but not `changed::picture-options`, so even a correct
  value would not repaint until something else forced a refresh.
  `bootstrap/paperwm-picture-options.py` fixes both, `40-extensions.sh`
  re-applies it every run, and `verify.sh` checks it — a PaperWM update
  replaces `tiling.js` and takes the patch with it silently.

- **Diagnose a "setting does nothing" by checking whether *every* value does
  nothing.** One wrong-looking value can be a bad value; *all* values being
  indistinguishable means nothing is reading the key, so stop tuning it and go
  find the reader. Here that pointed straight at the compositor extension and
  away from the setting, the image and the monitor layout.

- **You cannot screenshot-verify the desktop from a CLI on this machine.**
  `org.gnome.Shell.Screenshot` over D-Bus answers `AccessDenied` on GNOME 46
  (it is reserved for the screenshot UI), and `xwd -root` returns the desktop
  area as pure `0,0,0` — **ding** (Desktop Icons NG) owns two transparent
  full-screen windows (`xwininfo -root -children` shows `Desktop Icons 1`
  `2560x1600+0+0` and `Desktop Icons 2` `2560x1600+2560+0`) and the capture
  reads those rather than the wallpaper behind them. Do not try to prove a
  background change this way. Check the key with `gsettings get`, check the
  *reader* in source, and confirm the look by eye. Two captures taken under
  different `picture-options` values came back pixel-identical here — which
  was true but proved nothing, because PaperWM was ignoring the key anyway.

- **`ding`'s two per-monitor windows are not why a wallpaper repeats.** They
  are the obvious suspect and they are innocent: ding renders a transparent
  background and never reads `picture-uri` or `picture-options`.
- **starship exits 0 on a broken config.** Feed it a `starship.toml` with an
  unclosed table and `starship print-config` and `starship prompt` both return
  0; the `[ERROR] … Unable to parse the config file` goes to stderr and the
  default prompt is drawn. An unknown key or a missing palette is a `[WARN]`
  on stderr, again with exit 0, and it repeats at every prompt. A missing
  config file is silent. `verify.sh` therefore renders one prompt and fails on
  any stderr output at all, never on the exit code. Observed with 1.26.0.
- **A prompt with no icons is not necessarily a font problem.** starship drew
  the branch and language segments with no glyph in front of them, which reads
  as "the Nerd Font is missing or not active". It was neither: `fc-list` had
  all eight JetBrainsMono Nerd Font faces, `ghostty +show-config` resolved
  `font-family` to it, and `fc-list ":charset=f418"` proved the glyph was in
  the font. The cause was `starship.toml` itself — every `symbol = " "` was a
  bare `0x20`, committed that way (`xxd` on the line: `2220 220a`). Nerd Font
  glyphs live in Unicode's Private Use Area, render as blanks in most editors,
  and some write and paste paths drop them, so the file looked correct in
  every diff. Two traps in checking for it: `grep -oP '[\x{E000}-\x{F8FF}]'`
  needs a UTF-8 locale, and `sort -u` under `en_US.UTF-8` folds distinct PUA
  glyphs into one because they have no collation weight (seven became two) —
  `LC_ALL=C sort -u` keeps them apart. `verify.sh` now fails on a bare symbol
  and on any glyph the installed font lacks. Look at bytes, not at the screen.

### Useful commands

```bash
./install.sh --dry-run            # preview
./install.sh gnome dotfiles       # run a subset
./bootstrap/verify.sh             # check state; exit code = failure count
ALTER_SKIP_GHOSTTY=1 ./install.sh # skip the third-party PPA
ALTER_SKIP_FASTFETCH=1 ./install.sh  # ditto; banner falls back to plain
ALTER_SKIP_STARSHIP=1 ./install.sh   # keep the stock bash prompt
ALTER_STARSHIP_VERSION=v1.26.0 ./install.sh starship  # pin the prompt's release
starship explain                     # what each segment of the current prompt is
fastfetch --list-modules          # everything the banner could show
ALTER_WS_COUNT=6 ./install.sh     # more workspaces (1-9; pass the same to verify.sh)
ALTER_ROFI_KEY='<Super>w' ./install.sh
ghostty +list-keybinds --default  # ground truth before overriding anything
```

---

## What is deliberately *not* in here

This repo is meant to be pushed to GitHub, so it contains **no**:

- git identity (`user.name` / `user.email`) — set that yourself, per-machine
  or per-repo. `gitconfig.include` carries only tool config.
- `~/.bashrc` work section — SDK paths, internal project names, build aliases.
  Those stay in gitignored `local/env.sh`; the generic tooling hook sources it
  automatically when readable.
- `dconf` dumps — they include recent-file lists, app state, and account data.
  `20-gnome.sh` sets an explicit, reviewable list of keys instead.
- credentials, hostnames, or tokens of any kind.

Keep machine-specific config in `local/`, which is gitignored except for its
README. `config/shell/devtools.sh` sources `local/env.sh` when readable, from
`${ALTER_ROOT:-$HOME/alter}/local/env.sh`.

---

## Roadmap

Tracked in detail in **[`docs/TODO.md`](docs/TODO.md)**. What is left:

| Next | Item | Why |
|---|---|---|
| Phase 3 | **Multiplexer** (tmux) | Long builds still die with their terminal window |
| — | **Wayland session** | Better multi-monitor; blocked on rofi's window mode being X11-only |

Done since the first pass: PaperWM, Just Perfection, Clipboard Indicator, the
starship prompt, and a single Catppuccin Mocha palette across terminal,
launcher, pager, diffs and prompt.
