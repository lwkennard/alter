# CLAUDE.md — rules for this repo

Read [`README.md`](README.md) → "Working on this repo" for the general
conventions (idempotent, reversible, honest `--dry-run`, detect don't assume).
The rule below is in addition to those and is not optional.

---

## Rule: keep `keys` in sync with the settings it documents

`keys` prints [`docs/hotkeys.txt`](docs/hotkeys.txt) verbatim (see the `keys`
function in `config/shell/devtools.sh`). The file is read straight out of the
repo at `~/alter/docs/hotkeys.txt` — there is no copy or build step, so an edit
to it *is* the change to the printout.

**Any change to a keybinding or to a shell command/alias the reference
mentions — added, removed, or modified — must update `docs/hotkeys.txt` in the
same commit.** A change that leaves the printout stale is an incomplete change.

### What counts as a related setting

| Source | What it owns in the printout |
|---|---|
| `bootstrap/20-gnome.sh` | the `DESKTOP` block — workspace switching, move-to-workspace, `Super+Space`/rofi, anything unbound to free a key, `ALTER_WS_COUNT` / `ALTER_ROFI_KEY` behaviour |
| `config/ghostty/config` | the `TERMINAL -- GHOSTTY` block — every `keybind =` line, plus stock bindings this repo deliberately relies on |
| `config/shell/devtools.sh` | the `SHELL` block — fzf bindings, `z`/`zi`, the `ll`/`la`/`lt` aliases, `fd`/`rg`/`bat`, delta |
| `config/shell/greeting.sh` | the `SHELL` block lines about the new-terminal banner — `fetch`, the `logo.txt` path, `ALTER_NO_GREETING` |
| `config/rofi/config.rasi` | the keys inside the rofi menu (`kb-*`) and the window-switcher line |
| `bootstrap/40-extensions.sh` | the `WINDOWS -- PAPERWM` block — every PaperWM binding, `Super+V` for Clipboard Indicator, and the `PAPERWM TOOK OVER` block naming each stock binding it displaced |
| `bootstrap/verify.sh`, `uninstall.sh` | the `IF SOMETHING DOES NOT WORK` block |

A new `bootstrap/NN-*.sh` stage that sets keybindings joins this table; add its
row when you add the stage. An extension that ships its own bindings counts:
the user cannot tell which component bound a key, only that it does something.

### What to update

1. **`docs/hotkeys.txt`** — add, remove or correct the line. Then:
   - Keep the existing column alignment: keys start at column 4, the
     description at column 27, the `[stock]` marker at column 69 (75-char lines).
   - Mark `[stock]` only for bindings that came with GNOME/Ghostty and that
     this repo does *not* set. If the repo starts setting a key, drop the
     marker; if the repo stops setting one and the stock binding takes over,
     add it.
   - Keep each binding on **one self-contained line**. `keys PATTERN` greps the
     file, so a line that reads correctly only together with the line above it
     is invisible to a search.
   - When a key is deliberately *unbound*, say so on the line that now owns it
     (as `Super+1 .. 4` does with `(was dock favourites)`) rather than adding a
     separate line for the removal.
2. **`README.md`** — the keybinding sections near the top duplicate the same
   facts. Update them too, or the two references disagree.
3. **`bootstrap/verify.sh`** — if the change is a GNOME binding, add or adjust
   the `gsettings get` check, per the README convention that anything new gets
   a verify check.
4. **`uninstall.sh`** — if a new GNOME key is now set, make sure the reset path
   puts the default back.

### Check before finishing

```bash
./bootstrap/verify.sh          # exit 0 = state matches what is documented
keys                           # read the whole printout, not just your line
keys <the key you touched>     # the grep path must return your line alone
ghostty +list-keybinds         # ground truth for the Ghostty block
```

`docs/hotkeys.txt` is the one file a user reads at 2am when something stopped
working. Treat a wrong line in it as a bug of the same severity as a wrong line
in the shell config.

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
2. **Dry-run honest.** Route side effects through `run`. When `run` cannot
   express it — a shell redirect, for instance — guard explicitly, the way
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
