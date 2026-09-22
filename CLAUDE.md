# CLAUDE.md — rules for this repo

Read [`README.md`](README.md) → "Working on this repo" for the general
conventions (idempotent, reversible, honest `--dry-run`, detect don't assume).
The rules below are in addition to those and are not optional.

---

## Rule: worktree branches stay local — never push them to `origin`

A `worktree-*` branch (anything created under `.claude/worktrees/`) is a
scratch space for one job. It exists to keep parallel jobs and the user's
checkout from stepping on each other, not to be shared. **Commit on it as
much as you like; do not push it.** No `git push origin worktree-…`, no
`--set-upstream`, no `gh pr create` from it. The only branch that goes to
`origin` is `main`, and only through `bin/merge-latest` (or the user, by
hand).

Why: a pushed worktree branch is a remote branch someone has to notice,
review and delete later, and it leaks half-finished work off this machine.
Landing the work through `bin/merge-latest` gets it onto `origin/main` in one
step and, with `--clean`, removes the worktree and the branch afterwards.

- **Finished a job in a worktree?** Commit, leave the branch where it is,
  and say in your report which branch holds the work and that
  `bin/merge-latest` lands it. Do not push it "so it survives" — the local
  branch survives the worktree; only the worktree directory gets deleted.
- **Told to push, open a PR, or set an upstream from a worktree branch?**
  That is a change to this rule; check with the user first.
- **The `--clean` path in `bin/merge-latest`** deletes a `worktree-*` branch
  on `origin` only if it is already there. That is cleanup for branches
  pushed before this rule existed, not permission to push new ones.

---

## Rule: `docs/hotkeys.txt` is one fixed-height screen of keys and tools

`keys` prints [`docs/hotkeys.txt`](docs/hotkeys.txt) verbatim (see the `keys`
function in `config/shell/devtools.sh`). The file is read straight out of the
repo — no copy, no build step — so an edit to it *is* the change to the
printout. It exists to answer two questions and nothing else: **"what is the
hotkey to do X?"** and **"what do I type to use tool Y?"** — at a glance, with
every tool alter installs present, and no scrolling past the height budget.

`./bootstrap/verify.sh` enforces the shape and the tool coverage mechanically
(section "Hotkey reference"). A change that fails it is not finished.

### Shape — hard limits

| Limit | Value | Why |
|---|---|---|
| Height | **≤ 50 lines**, borders included | the chosen budget: one tall terminal, no paging |
| Width | **≤ 72 characters** per line | fits the narrowest window the file is read in |
| Border | line 1 and the last line are blank; **no other blank lines** | one line of air above and below the text; a blank line inside is an entry that did not fit |
| Line kinds | exactly two between the borders | a **section header** (`␣NAME`, upper case, one leading space) or an **entry** (key or command at column 4, description at column 27) |
| Key/command column | ≤ 22 characters | columns 4–25; column 26 is the separating space |
| Description | ≤ 46 characters | columns 27–72 |

The budget is fixed. **Adding a line means removing or merging another once
the file is full.** When you must choose, keep what a user cannot guess and
cannot look up elsewhere, in this order: repo-set keys that replaced a stock
key → the one line each tool is owed (below) → PaperWM keys → stock keys
people forget → stock keys everyone knows. Anything cut moves to the README's
"Not in `keys`" table, so it is still findable — just not in `keys`.

### Coverage — every tool gets a line

Every tool alter installs has **at least one entry**, even a tool with no
hotkey: for those the command is the key (`z DIR / zi / z -`, `bat FILE`,
`fetch`). `verify.sh` checks the list below by pattern; a new tool added to
`APT_PKGS`, a `bootstrap/NN-*.sh` install stage (Ghostty, fastfetch,
starship) or the extension `WANT` list joins
this table, the `hotkeys.txt` `SHELL` (or fitting) section, and the
`verify.sh` pair list in the same commit.

| Tool | Its line | Proven by |
|---|---|---|
| rofi | `Super+Space` and the `rofi:` lines under `DESKTOP` | `rofi` |
| PaperWM | the `WINDOWS (PAPERWM)` section | `PAPERWM` |
| Clipboard Indicator | `Super+V  clipboard history` | `clipboard` |
| Ghostty | the `TERMINAL (GHOSTTY)` section | `GHOSTTY` |
| fzf | `Ctrl+R`, `Ctrl+T / Alt+C` | `(fzf)` |
| zoxide | `z DIR / zi / z -` | `(zoxide)` |
| eza | `ll / la / lt` | `(eza)` |
| bat | `bat FILE` | `^   bat ` |
| fd-find | `fd PATTERN` | `^   fd ` |
| ripgrep | `rg PATTERN` | `^   rg ` |
| git-delta | `git diff / show / log` | `delta` |
| gh | `gh` | `^   gh ` |
| fastfetch | `fetch` | `(fastfetch)` |
| starship | `starship explain` | `^   starship ` |
| `keys` itself | `keys [PATTERN]` | `^   keys ` |

Just Perfection, the Nerd Font and the Catppuccin theme have no key and no
command, so they have no line; they are described in `README.md`.

### Content — what a line may say

- **Keys and commands only.** An entry names a key, a key family, or the
  command that invokes a tool, and the action it performs. No environment
  variables, file paths, flags lists or troubleshooting steps — those are
  documented in `README.md` ("What you get", "The terminal greeting", "Useful
  commands").
- **No rationale, no history, no comparison.** Nothing about what a key *used
  to* do, what GNOME or Ghostty bind by default, what this repo changed, or
  why. No `[stock]` marker, no `(was …)`, no "instead of", no "replaces".
  `verify.sh` greps for these words and fails on them. That story belongs in
  `README.md` → "Keybindings" and in comments next to the setting.
- **No title, no legend.** The first line after the border is the first
  section header. `keys` has its own entry (`keys [PATTERN]`) and nothing more.
- **The description is the action**, in plain words, as short as it can be
  while still unambiguous: `close window`, `move tab left / right`. A tool
  name in parentheses at the end is allowed and is how a tool's line is found
  (`(fzf)`, `(eza)`). The one other allowed qualifier is a per-machine variant
  on the same line, e.g. `Super+W with 2+ layouts`.
- **One self-contained line per entry.** `keys PATTERN` greps the file, so a
  line must read correctly on its own. Sibling keys that share one action may
  share a line, split with ` / ` on both sides (`Ctrl+Shift+T / W` →
  `new / close tab`). `X / +Mod` means the same key with `Mod` added
  (`Super+R / +Shift` → `cycle window width / height`).
- **Sections are fixed:** `DESKTOP`, `WINDOWS (PAPERWM)`, `TERMINAL
  (GHOSTTY)`, `SHELL`, in that order. Tool commands live under `SHELL`. A new
  section is only justified by a new component that binds its own keys — and
  it still has to fit the height budget.
- **Key spelling:** `Super`, `Ctrl`, `Alt`, `Shift`, `+` between modifiers,
  `Left/Right/Up/Down` or `arrows`, `PgUp/PgDn`, `Return`, `BackSpace`,
  `Escape`, `Tab`, `1..4`. Command placeholders are upper case: `DIR`, `FILE`,
  `PATTERN`; optional ones in brackets: `[PATTERN]`. Match the existing lines;
  do not introduce a second spelling of the same key.

### Sync — what owns which lines

**Any change to a keybinding or to a tool's invoking command — added, removed,
or modified — must update `docs/hotkeys.txt` in the same commit.** A stale
printout is an incomplete change.

| Source | What it owns in the printout |
|---|---|
| `bootstrap/20-gnome.sh` | `DESKTOP` — workspace switching, move-to-workspace, `Super+Space`/rofi (and the `Super+W` variant), `ALTER_WS_COUNT` / `ALTER_ROFI_KEY` behaviour |
| `bootstrap/40-extensions.sh` | `WINDOWS (PAPERWM)` — every PaperWM binding the repo sets, unbinds or relies on; `Super+V` for Clipboard Indicator under `DESKTOP` |
| `config/ghostty/config` | `TERMINAL (GHOSTTY)` — every `keybind =` line, plus the stock bindings the repo deliberately relies on |
| `config/shell/devtools.sh` | `SHELL` — the fzf key bindings, the `z`/`zi`, `ll`/`la`/`lt`, `bat`, `fd`, `rg` lines, and `keys` |
| `config/git/gitconfig.include` | the `git diff / show / log` (delta) line |
| `config/shell/greeting.sh` | the `fetch` line |
| `bootstrap/00-packages.sh` | one line per package in `APT_PKGS`, plus Ghostty and fastfetch |
| `bootstrap/05-starship.sh`, `config/starship/starship.toml` | the `starship explain` line |
| `config/rofi/config.rasi` | the `rofi:` lines — the `kb-*` keys that made the cut; the README carries the rest |

A new `bootstrap/NN-*.sh` stage that sets keybindings or installs a tool joins
this table when you add the stage. An extension that ships its own bindings
counts: the user cannot tell which component bound a key, only that it does
something.

### What to update

1. **`docs/hotkeys.txt`** — add, remove or correct the line within the shape
   limits above. Keys stay conventional-looking and aligned with their
   neighbours.
2. **`README.md`** → "Keybindings" and "What you get" — the same facts, with
   the rationale and history that `hotkeys.txt` is not allowed to carry.
   Bindings dropped from `hotkeys.txt` for space go in the "Not in `keys`"
   table there. Update it, or the two references disagree.
3. **`bootstrap/verify.sh`** — for a GNOME binding, add or adjust the
   `gsettings get` check, per the README convention that anything new gets a
   verify check. For a new tool, add its `name:pattern` pair to the coverage
   loop. If you change a shape limit, change `HK_MAX_LINES` / `HK_MAX_COLS`
   there **and** in the table above, in the same commit, and say in the
   commit why the budget moved.
4. **`uninstall.sh`** — if a new GNOME key is now set, make sure the reset path
   puts the default back.

### Check before finishing

```bash
./bootstrap/verify.sh          # "Hotkey reference" section all ✓, exit 0
keys                           # read the whole printout; the blank borders are part of it
keys <the key you touched>     # the grep path must return your line alone, and it must make sense alone
ghostty +list-keybinds         # ground truth for the Ghostty block
```

`docs/hotkeys.txt` is the one file a user reads at 2am when something stopped
working. A wrong line in it is a bug of the same severity as a wrong line in
the shell config; a line that pushes it past the budget, or a tool with no
line at all, is the same bug.

---

## Rule: every effectual change to the workstation lands in the setup scripts

If you change something on this machine that has an effect — a gsettings key, an
installed package, a symlinked config, a shell hook, a default application, a
font, an apt source — **the change is not finished until `./install.sh`
reproduces it on a fresh machine, `verify.sh` checks it, and `uninstall.sh`
undoes it.** Doing it by hand and moving on guarantees the next setup, on the
next machine or after the next reinstall, walks into the same wall.

The machine is disposable. This repo is the state.

### Where the change goes

| Change | Lands in |
|---|---|
| apt package | `APT_PKGS` in `bootstrap/00-packages.sh` |
| font | the `WANT` list in `bootstrap/10-fonts.sh` |
| gsettings / dconf key | `bootstrap/20-gnome.sh`, as a `gset` line |
| new or edited dotfile | a file under `config/`, plus a `link` line in `bootstrap/30-dotfiles.sh` |
| line in `~/.bashrc` / `~/.bash_profile` | `append_once` with a marker string, in `30-dotfiles.sh` |
| default application, `update-alternatives` | `bootstrap/30-dotfiles.sh` |
| a whole new category of setup | `bootstrap/NN-name.sh`, added to `STAGES` **and** `MOD` in `install.sh` |
| machine-specific or private | gitignored `local/` — never a bootstrap stage |

### Every such change must be

1. **Idempotent.** `gset`, `link` and `append_once` already are; anything new
   must detect its own prior work and `skip` on the second run.
2. **Dry-run honest.** Route side effects through `run`; use `runq` when a
   command's own output should be hidden, since `run cmd >/dev/null` also
   swallows the `[dry-run]` line. When `run` cannot express a side effect — a
   shell redirect, for instance — guard explicitly, the way
   `30-dotfiles.sh` writes `xdg-terminals.list` behind `[ "$DRY_RUN" = 1 ] ||`.
3. **Guarded, not assumed.** `have`, `is_gnome`, `is_debianish`, `gnome_ver`.
   Warn and skip on a machine that does not match; never fail the whole run.
4. **Verified.** Add a check to `bootstrap/verify.sh`. Hard requirement →
   `err` + `fails=$((fails+1))`; nice-to-have → `warn` only.
5. **Reversible.** If it writes anything outside the repo, `uninstall.sh` must
   reset or unlink it — or, if it genuinely cannot be automated, name it under
   that script's "Manual leftovers".

### Capturing a change you made through a GUI

Do not write down the click path; capture the key it actually set.

```bash
dconf watch /                 # leave running, make the change in Settings
gsettings get <schema> <key>  # confirm the value and its exact quoting
```

Then encode it as a `gset` line so the GUI visit never has to happen again.

### Record the problem, not just the fix

This is the part that keeps a later setup from re-solving it:

- **It cost you debugging time, and the fix is in** → add it to "Gotchas found
  the hard way" in [`README.md`](README.md): the symptom, the cause, and the
  evidence that proved it. The existing entries are the model — they cite the
  actual observation (`PIPESTATUS: 141 0`), not a vague warning.
- **It is not fixed, or needs revisiting** → a row in the "Open loose ends"
  table in [`docs/TODO.md`](docs/TODO.md), including how to confirm it next
  time.
- **It depends on a version, a distro or a third-party source** → say so in a
  comment at the point of use, as `GHOSTTY_PPA` does about Ubuntu 26.04.
- **It changes a keybinding** → the `keys` rule above applies as well.

A fix with no record is a fix you will pay for twice.

### Check before finishing

```bash
./install.sh --dry-run          # every side effect prints as [dry-run]; nothing runs
./install.sh <stage>            # for real
./install.sh <stage>            # again: second run must be all skips, no changes
./bootstrap/verify.sh           # exit 0
DRY_RUN=1 ./uninstall.sh        # your change must show up in the revert path
```
