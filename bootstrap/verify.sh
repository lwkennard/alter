#!/usr/bin/env bash
# Check that the setup actually took. Exits non-zero on hard failures.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
fails=0

hdr "Binaries"
for c in rofi fzf zoxide fdfind batcat eza delta gh ghostty starship; do
  if have "$c"; then ok "$c -> $(command -v "$c")"
  elif [ "$c" = ghostty ] && [ "${ALTER_SKIP_GHOSTTY:-0}" = 1 ]; then warn "ghostty not installed (ALTER_SKIP_GHOSTTY=1)"
  elif [ "$c" = starship ] && [ "${ALTER_SKIP_STARSHIP:-0}" = 1 ]; then warn "starship not installed (ALTER_SKIP_STARSHIP=1)"
  else err "$c MISSING"; fails=$((fails+1)); fi
done

hdr "Font"
fc-list : family 2>/dev/null | grep -F 'JetBrainsMono Nerd Font' >/dev/null \
  && ok "JetBrainsMono Nerd Font present" || { err "Nerd Font MISSING"; fails=$((fails+1)); }
# The prompt's icons are Nerd Font glyphs from Unicode's Private Use Area
# (U+E000-F8FF and U+F0000-FFFFD). Editors draw them as blanks and some paste
# paths drop them outright, so `symbol = " "` -- a bare space -- looks right in
# a diff and prints nothing at the prompt while the font itself is fine (see
# README "Gotchas"). Require a glyph on every symbol line, and require the
# installed font to carry every glyph the file uses -- that second check also
# catches codepoints Nerd Fonts moved between major releases.
_st="$ALTER_ROOT/config/starship/starship.toml"
_bare=$(grep -nE '^symbol = " ?"$' "$_st" | cut -d: -f1 | paste -sd,)
[ -z "$_bare" ] && ok "starship.toml: every symbol carries a glyph" \
  || { err "starship.toml: bare symbol, no glyph, on line(s) $_bare"; fails=$((fails+1)); }
# LC_ALL=C on the sort is load-bearing: under en_US.UTF-8 these glyphs have no
# collation weight, compare equal, and `sort -u` folds seven of them into two.
_missing=""
for _cp in $(LC_ALL=C.UTF-8 grep -oP '[\x{E000}-\x{F8FF}\x{F0000}-\x{FFFFD}]' "$_st" 2>/dev/null | LC_ALL=C sort -u | tr -d '\n' \
             | iconv -f UTF-8 -t UTF-32BE | od -An -tx4 -v -w4 --endian=big | tr -d ' ' | sed 's/^0*//'); do
  fc-list ":charset=$_cp" family 2>/dev/null | grep -qF 'JetBrainsMono Nerd Font' || _missing="$_missing U+${_cp^^}"
done
[ -z "$_missing" ] && ok "every glyph starship.toml uses is in JetBrainsMono Nerd Font" \
  || { err "starship.toml uses glyphs the installed font lacks:$_missing"; fails=$((fails+1)); }

hdr "Configs parse"
if have ghostty; then
  ghostty +validate-config --config-file="$HOME/.config/ghostty/config" >/dev/null 2>&1 \
    && ok "ghostty config valid" || { err "ghostty config INVALID"; fails=$((fails+1)); }
  # Split navigation is the one binding this repo moves off a Ghostty default,
  # so confirm all four directions actually landed.
  n=$(ghostty +list-keybinds 2>/dev/null | grep -c 'ctrl+shift+arrow_.*=goto_split:')
  [ "${n:-0}" = 4 ] && ok "Ctrl+Shift+arrows -> move between splits" \
    || { err "Ctrl+Shift+arrows split navigation: $n/4 bound"; fails=$((fails+1)); }
  # No Ghostty notification may reach the GNOME tray (see the config comment).
  # +show-config omits values equal to the default, so an absent
  # notify-on-command-finish means 'never'.
  _gc=$(ghostty +show-config 2>/dev/null)
  if grep -qx 'desktop-notifications = false' <<<"$_gc" \
     && grep -q '^bell-features = .*no-attention' <<<"$_gc" \
     && ! grep -q '^notify-on-command-finish = [^n]' <<<"$_gc"; then
    ok "ghostty sends no desktop notifications"
  else
    err "ghostty desktop notifications not fully disabled"; fails=$((fails+1))
  fi
fi
if have rofi; then
  rofi -dump-config >/dev/null 2>&1 && ok "rofi config parses" || { err "rofi config ERROR"; fails=$((fails+1)); }
  # rofi 1.7.5 exits 0 even when the theme fails to parse: it reports the error
  # in the launcher overlay and nowhere else -- stderr stays empty when the
  # theme is reached through config.rasi's @theme line. The one signal the CLI
  # gives is that -dump-theme prints NOTHING on failure and ~2KB on success, so
  # test the output, never the exit code. (See README "Gotchas".)
  if [ -n "$(rofi -dump-theme 2>/dev/null)" ]; then
    ok "rofi theme parses"
  else
    err "rofi theme ERROR (rofi -dump-theme printed nothing)"
    say "    which file: rofi -no-config -theme ~/.config/rofi/themes/catppuccin-mocha.rasi -dump-theme"
    say "    line+column: press the rofi key; the overlay shows the parser error"
    fails=$((fails+1))
  fi
fi

hdr "Dotfiles"
# Every `link` in 30-dotfiles.sh. A config that is not linked is not loaded.
for f in ghostty/config rofi/config.rasi rofi/themes/catppuccin-mocha.rasi \
         shell/devtools.sh shell/greeting.sh fastfetch/config.jsonc fastfetch/logo.txt \
         "bat/themes/Catppuccin Mocha.tmTheme"; do
  [ -L "$HOME/.config/$f" ] && [ "$(readlink -f "$HOME/.config/$f")" = "$(readlink -f "$ALTER_ROOT/config/$f")" ] \
    && ok "~/.config/$f linked" || { err "~/.config/$f is not linked to the repo (run: ./install.sh dotfiles)"; fails=$((fails+1)); }
done
[ "$(readlink -f "$HOME/.local/bin/zenity-askpass" 2>/dev/null)" = "$(readlink -f "$ALTER_ROOT/bin/zenity-askpass")" ] \
  && ok "~/.local/bin/zenity-askpass linked" || warn "~/.local/bin/zenity-askpass not linked"
# starship reads ~/.config/starship.toml, not a per-tool directory, so it does
# not fit the loop above.
[ -L "$HOME/.config/starship.toml" ] && [ "$(readlink -f "$HOME/.config/starship.toml")" = "$(readlink -f "$ALTER_ROOT/config/starship/starship.toml")" ] \
  && ok "~/.config/starship.toml linked" || { err "~/.config/starship.toml is not linked to the repo (run: ./install.sh dotfiles)"; fails=$((fails+1)); }
for m in config/shell/devtools.sh config/shell/greeting.sh; do
  grep -qF "$m" "$HOME/.bashrc" 2>/dev/null \
    && ok "~/.bashrc sources ${m##*/}" || { err "~/.bashrc does not source ${m##*/} (run: ./install.sh dotfiles)"; fails=$((fails+1)); }
done
git config --global --get-all include.path 2>/dev/null | grep -qxF "$ALTER_ROOT/config/git/gitconfig.include" \
  && ok "git includes config/git/gitconfig.include" || warn "git include.path for gitconfig.include missing"

hdr "Shell integration"
# readline bindings only exist under a real pty, so allocate one
if have script; then
  out=$(script -qec 'bash -i -c "bind -X 2>/dev/null"' /dev/null 2>/dev/null | tr -d '\r')
  printf '%s' "$out" | grep -q '__fzf_history__'  && ok "Ctrl+R -> fzf history"     || { warn "Ctrl+R binding not detected"; }
  printf '%s' "$out" | grep -q 'fzf-file-widget'  && ok "Ctrl+T -> fzf file widget" || { warn "Ctrl+T binding not detected"; }
fi
bash -c '. "$HOME/.config/shell/devtools.sh"; type -t __zoxide_z' 2>/dev/null | grep -q function \
  && ok "zoxide initialised" || { err "zoxide NOT initialised"; fails=$((fails+1)); }
if have starship; then
  # `starship init bash` defines starship_precmd and puts it in PROMPT_COMMAND;
  # if devtools.sh did not run it the stock Ubuntu PS1 is what you get.
  bash -c '. "$HOME/.config/shell/devtools.sh"; type -t starship_precmd' 2>/dev/null | grep -q function \
    && ok "starship prompt initialised" || { err "starship NOT initialised by devtools.sh"; fails=$((fails+1)); }
  # starship exits 0 whatever the config says: a TOML syntax error, an unknown
  # key and a missing palette are all reported on stderr -- at every prompt --
  # while `starship prompt` and `print-config` still return 0 (same trap as
  # rofi -dump-theme; see README "Gotchas"). So render one prompt from the
  # repo and require silence.
  _se=$(cd "$ALTER_ROOT" && starship prompt 2>&1 >/dev/null)
  if [ -z "$_se" ]; then
    ok "starship.toml renders a prompt with no warnings"
  else
    err "starship.toml problem (starship prompt wrote to stderr):"
    printf '%s\n' "$_se" | sed 's/^/    /' >&2; fails=$((fails+1))
  fi
fi

hdr "GNOME"
if is_gnome; then
  ws="${ALTER_WS_COUNT:-4}"; case "$ws" in [1-9]) ;; *) ws=4 ;; esac   # same rule as 20-gnome.sh
  v=$(gsettings get org.gnome.desktop.wm.preferences num-workspaces 2>/dev/null)
  d=$(gsettings get org.gnome.mutter dynamic-workspaces 2>/dev/null)
  [ "$v" = "$ws" ] && [ "$d" = false ] && ok "$ws fixed workspaces" \
    || warn "num-workspaces=$v dynamic-workspaces=$d (expected $ws, false)"
  _dock=0; _hot=0; gsettings list-schemas 2>/dev/null | grep -qx org.gnome.shell.extensions.dash-to-dock && _dock=1
  for i in $(seq 1 "$ws"); do
    v=$(gsettings get org.gnome.desktop.wm.keybindings "switch-to-workspace-$i" 2>/dev/null)
    [ "$v" = "['<Super>$i']" ] && ok "Super+$i -> workspace $i" \
      || { err "switch-to-workspace-$i is $v (expected ['<Super>$i'])"; fails=$((fails+1)); }
    v=$(gsettings get org.gnome.desktop.wm.keybindings "move-to-workspace-$i" 2>/dev/null)
    [ "$v" = "['<Super><Shift>$i']" ] && ok "Super+Shift+$i -> move window to workspace $i" \
      || { err "move-to-workspace-$i is $v (expected ['<Super><Shift>$i'])"; fails=$((fails+1)); }
    # GNOME's app-switching and the Ubuntu dock both ship on Super+N; either one
    # left bound means Super+N does two things.
    v=$(gsettings get org.gnome.shell.keybindings "switch-to-application-$i" 2>/dev/null)
    [ "$v" = "@as []" ] || { err "switch-to-application-$i is $v -- collides with Super+$i"; fails=$((fails+1)); _hot=1; }
    if [ "$_dock" = 1 ]; then
      v=$(gsettings get org.gnome.shell.extensions.dash-to-dock "app-hotkey-$i" 2>/dev/null)
      [ "$v" = "@as []" ] || { err "dash-to-dock app-hotkey-$i is $v -- collides with Super+$i"; fails=$((fails+1)); _hot=1; }
    fi
  done
  [ "$_hot" = 0 ] && ok "Super+1..$ws free of app-switching and dock hotkeys"
  v=$(gsettings get org.gnome.mutter workspaces-only-on-primary 2>/dev/null)
  [ "$v" = false ] && ok "second monitor joins workspaces" || warn "workspaces-only-on-primary=$v"
  # Cosmetic, so a warn: any other value still draws a wallpaper, just one
  # independently-scaled copy per monitor instead of a single spanned image.
  v=$(gsettings get org.gnome.desktop.background picture-options 2>/dev/null)
  [ "$v" = "'spanned'" ] \
    && ok "wallpaper spans all monitors" \
    || warn "picture-options=$v (a separate copy on each monitor; expected 'spanned')"
  # Super+Shift+Left/Right moves the window to the prev/next workspace. GNOME
  # ships move-to-monitor-* on the same chord, so those must be empty -- and
  # PaperWM must not hold it (its switch-monitor moved to Super+Shift+Alt) nor
  # have move-to-monitor-* queued in restore-keybinds, which it replays on every
  # shell start. Any of the three means two actions on one key: fail.
  for d in Left Right; do
    lc=$(printf '%s' "$d" | tr 'A-Z' 'a-z')
    v=$(gsettings get org.gnome.desktop.wm.keybindings "move-to-workspace-$lc" 2>/dev/null)
    [ "$v" = "['<Super><Shift>$d']" ] \
      && ok "Super+Shift+$d -> move window to $lc workspace" \
      || { err "move-to-workspace-$lc is $v (expected ['<Super><Shift>$d'])"; fails=$((fails+1)); }
  done
  _mm=""
  for d in left right up down; do
    v=$(gsettings get org.gnome.desktop.wm.keybindings "move-to-monitor-$d" 2>/dev/null)
    [ "$v" = "@as []" ] || _mm="$_mm move-to-monitor-$d=$v"
  done
  [ -z "$_mm" ] && ok "stock move-to-monitor unbound (frees Super+Shift+arrows)" \
    || { err "still bound:$_mm -- collides with Super+Shift+arrows"; fails=$((fails+1)); }
  # Exactly one binding per direction: Super+Alt+arrows. GNOME ships three
  # aliases; the extras are trimmed so Ctrl+Alt+arrows and Super+PgUp/PgDn stay
  # free. A leftover alias is a warn, not a failure -- nothing breaks, it is
  # just the clutter this repo removed coming back.
  for d in Left Right; do
    lc=$(printf '%s' "$d" | tr 'A-Z' 'a-z')
    v=$(gsettings get org.gnome.desktop.wm.keybindings "switch-to-workspace-$lc" 2>/dev/null)
    [ "$v" = "['<Super><Alt>$d']" ] \
      && ok "Super+Alt+$d -> workspace $lc (sole binding)" \
      || warn "switch-to-workspace-$lc is $v (expected ['<Super><Alt>$d'])"
  done
  # The rofi custom keybinding 20-gnome.sh registers, found by name as it is.
  _rofi=""
  for p in $(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null \
             | grep -oE "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/[^/']+/"); do
    _s="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$p"
    [ "$(gsettings get "$_s" name 2>/dev/null)" = "'Rofi window switcher'" ] || continue
    [ "$(gsettings get "$_s" command 2>/dev/null)" = "'rofi -show window'" ] && _rofi=$(gsettings get "$_s" binding 2>/dev/null | tr -d "'")
  done
  # Expected key: same rule as 20-gnome.sh -- ALTER_ROFI_KEY, else Super+Space
  # with one input source and Super+W when Super+Space switches sources.
  _want="${ALTER_ROFI_KEY:-}"
  if [ -z "$_want" ]; then
    _src=$(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null | grep -o "('xkb'\|('ibus'" | wc -l)
    if [ "$_src" -le 1 ]; then _want='<Super>space'; else _want='<Super>w'; fi
  fi
  if [ "$_rofi" = "$_want" ]; then
    ok "$_rofi -> rofi window switcher"
  else
    err "rofi window switcher is on '${_rofi:-nothing}', expected '$_want' (run: ./install.sh gnome)"; fails=$((fails+1))
  fi
  if [ "$_rofi" = "<Super>space" ]; then
    v="$(gsettings get org.gnome.desktop.wm.keybindings switch-input-source 2>/dev/null)$(gsettings get org.gnome.desktop.wm.keybindings switch-input-source-backward 2>/dev/null)"
    [ "$v" = "@as []@as []" ] && ok "input-source switching off Super+Space" \
      || { err "switch-input-source still bound -- collides with rofi on Super+Space"; fails=$((fails+1)); }
  fi
  v=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)
  [ "$v" = "'prefer-dark'" ] && ok "dark colour scheme" || warn "color-scheme=$v (expected 'prefer-dark')"
fi

hdr "Default terminal"
if have ghostty; then
  # xdg-terminal-exec uses the first entry; GNOME Terminal puts itself first
  # when made the default, so this drifts without anyone running install.sh.
  _xt=$(head -1 "$HOME/.config/${XDG_CURRENT_DESKTOP%%:*}-xdg-terminals.list" 2>/dev/null)
  [ -n "$_xt" ] || _xt=$(head -1 "$HOME/.config/xdg-terminals.list" 2>/dev/null)
  [ "$_xt" = com.mitchellh.ghostty.desktop ] && ok "xdg-terminals.list prefers ghostty" \
    || warn "xdg-terminals.list prefers ${_xt:-nothing} (re-run: ./install.sh dotfiles)"
  if is_gnome; then
    v=$(gsettings get org.gnome.desktop.default-applications.terminal exec 2>/dev/null)
    [ "$v" = "'ghostty'" ] && ok "GNOME default terminal is ghostty" || warn "default-applications.terminal exec=$v"
  fi
fi


hdr "Palette (Catppuccin Mocha)"
_bat=$(command -v batcat || command -v bat) || true
if [ -n "${_bat:-}" ]; then
  "$_bat" --list-themes 2>/dev/null | grep -qx "Catppuccin Mocha" \
    && ok "bat knows Catppuccin Mocha" || { err "bat theme MISSING (run: bat cache --build)"; fails=$((fails+1)); }
fi
[ "$(git config --get delta.features)" = "catppuccin-mocha" ] \
  && ok "delta uses catppuccin-mocha" || warn "delta.features is not catppuccin-mocha"
grep -q 'Catppuccin Mocha' "$HOME/.config/ghostty/config" 2>/dev/null \
  && ok "ghostty theme is Catppuccin Mocha" || warn "ghostty theme not set"
grep -qx 'palette = "catppuccin_mocha"' "$HOME/.config/starship.toml" 2>/dev/null \
  && ok "starship palette is catppuccin_mocha" || warn "starship palette not set"

hdr "Extensions"
if is_gnome && have gnome-extensions; then
  # PaperWM overrides GNOME's desktop with a per-monitor background actor per
  # space and upstream hardcodes BackgroundStyle.ZOOM, which makes every value
  # of picture-options a no-op. 40-extensions.sh patches that. A PaperWM update
  # replaces tiling.js and silently takes the patch with it, so check it here --
  # warn, not fail: the desktop still works, it just repeats on each monitor.
  _pwm_tiling="$HOME/.local/share/gnome-shell/extensions/paperwm@paperwm.github.com/tiling.js"
  if [ ! -f "$_pwm_tiling" ]; then
    skip "PaperWM not installed; no background patch to check"
  elif python3 "$ALTER_ROOT/bootstrap/paperwm-picture-options.py" check "$_pwm_tiling" >/dev/null 2>&1; then
    ok "PaperWM honours picture-options (wallpaper can span monitors)"
  else
    warn "PaperWM tiling.js is unpatched: picture-options is ignored and the"
    say  "    wallpaper repeats on each monitor. Re-run: ./install.sh extensions"
  fi
  # The master switch first: while disable-user-extensions is true every check
  # below is meaningless, because nothing under ~/.local/share ever loads.
  _due=$(gsettings get org.gnome.shell disable-user-extensions 2>/dev/null)
  if [ "$_due" = false ]; then
    ok "user extensions allowed to load"
  else
    err "disable-user-extensions=$_due -- NO user extension loads (run: ./install.sh extensions)"
    fails=$((fails+1))
  fi
  _en=$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null)
  # Listed-and-enabled is not the same as running. An extension that is present,
  # listed and still INITIALIZED has never been loaded into gnome-shell: that is
  # exactly the state the master switch above produces, and it must fail here
  # rather than print a reassuring tick.
  for u in paperwm@paperwm.github.com just-perfection-desktop@just-perfection clipboard-indicator@tudmotu.com; do
    if ! printf '%s' "$_en" | grep -q "$u"; then
      err "$u NOT enabled"; fails=$((fails+1)); continue
    fi
    _state=$(gnome-extensions info "$u" 2>/dev/null | awk -F': ' '/State:/{print $2}')
    case "$_state" in
      ACTIVE)  ok "$u (ACTIVE)" ;;
      "")      err "$u not installed"; fails=$((fails+1)) ;;
      *)       err "$u is $_state, not ACTIVE -- listed but never loaded (restart GNOME Shell)"
               fails=$((fails+1)) ;;
    esac
  done
  # PaperWM's duplicate workspace/monitor keys must stay unbound, or they
  # double-fire against the Super+Alt+arrows bindings 20-gnome.sh sets.
  _pwd="$HOME/.local/share/gnome-shell/extensions/paperwm@paperwm.github.com/schemas"
  if [ -d "$_pwd" ]; then
    _bad=0
    for k in switch-up-workspace switch-down-workspace move-up-workspace \
             move-down-workspace swap-monitor-left swap-monitor-right \
             center-vertically; do
      v=$(gsettings --schemadir "$_pwd" get org.gnome.shell.extensions.paperwm.keybindings "$k" 2>/dev/null)
      [ "$v" = "@as []" ] || { warn "PaperWM $k is $v (should be unbound)"; _bad=1; }
    done
    [ "$_bad" = 0 ] && ok "PaperWM duplicate keys unbound"
    for p in left:Left right:Right above:Up below:Down; do
      v=$(gsettings --schemadir "$_pwd" get org.gnome.shell.extensions.paperwm.keybindings "switch-monitor-${p%%:*}" 2>/dev/null)
      [ "$v" = "['<Super><Shift><Alt>${p#*:}']" ] \
        && ok "Super+Shift+Alt+${p#*:} -> PaperWM focus monitor ${p%%:*}" \
        || { err "PaperWM switch-monitor-${p%%:*} is $v (expected ['<Super><Shift><Alt>${p#*:}'])"; fails=$((fails+1)); }
    done
    v=$(gsettings --schemadir "$_pwd" get org.gnome.shell.extensions.paperwm restore-keybinds 2>/dev/null)
    case "$v" in
      *'"move-to-monitor-'*|*'"move-to-workspace-'*)
         err "PaperWM restore-keybinds holds move-to-{monitor,workspace}-*; it replays them on shell start / disable (re-run: ./install.sh extensions)"
         fails=$((fails+1)) ;;
      *) ok "PaperWM will not restore move-to-{monitor,workspace}-*" ;;
    esac
  fi
  _cid="$HOME/.local/share/gnome-shell/extensions/clipboard-indicator@tudmotu.com/schemas"
  if [ -d "$_cid" ]; then
    v=$(gsettings --schemadir "$_cid" get org.gnome.shell.extensions.clipboard-indicator toggle-menu 2>/dev/null)
    [ "$v" = "['<Super>v']" ] && ok "Super+V -> clipboard history" || warn "Clipboard Indicator toggle-menu is $v (expected ['<Super>v'])"
  fi
  # Ubuntu's extensions are enabled by DEFAULT and never appear in
  # enabled-extensions, so grepping that list always "passes" no matter what
  # tiling-assistant is really doing. Ask the shell for its actual state.
  _ta=$(gnome-extensions info tiling-assistant@ubuntu.com 2>/dev/null \
        | awk -F': ' '/Enabled:/{print $2}')
  case "$_ta" in
    ""|No) ok "tiling-assistant disabled (PaperWM owns tiling)" ;;
    *)     err "tiling-assistant is still enabled -- fights PaperWM for every window"
           fails=$((fails+1)) ;;
  esac
fi

hdr "Greeting"
if have fastfetch; then
  ok "fastfetch -> $(command -v fastfetch)"
else
  warn "fastfetch not installed; the greeting falls back to its plain banner"
  say  "    ./install.sh packages   (ppa:zhangsongcui3371/fastfetch on Ubuntu < 24.10)"
fi
# grep -c '', not wc -l: the art deliberately ends without a newline (fastfetch
# would draw that as an extra blank row) and wc would report one line short.
_art=$(grep -c '' "$HOME/.config/fastfetch/logo.txt" 2>/dev/null)
if [ -s "$HOME/.config/fastfetch/logo.txt" ]; then
  ok "logo.txt present ($_art rows of art)"
else
  err "logo.txt MISSING or empty -- the banner has no picture"; fails=$((fails+1))
fi
# The two columns are independent, so nothing breaks if they differ -- the
# banner just ends ragged. Warn, because it is the kind of thing you stop
# seeing after a week.
if have fastfetch && [ -n "$_art" ]; then
  _panel=$(fastfetch --config "$HOME/.config/fastfetch/config.jsonc" --logo none --pipe 2>/dev/null | grep -c .)
  [ "$_art" = "$_panel" ] \
    && ok "art and info panel are both $_art rows" \
    || warn "art is $_art rows, the info panel is $_panel -- the banner ends ragged"
fi
if have fastfetch && [ -f "$HOME/.config/fastfetch/config.jsonc" ]; then
  # Exit code catches a JSONC syntax error (221) and nothing else: a module
  # name fastfetch does not know is dropped in silence, exit 0, no message --
  # a typo in one entry can empty the whole banner. So count the output too.
  if ! fastfetch --config "$HOME/.config/fastfetch/config.jsonc" --pipe >/dev/null 2>&1; then
    err "fastfetch config INVALID: fastfetch --config ~/.config/fastfetch/config.jsonc"
    fails=$((fails+1))
  elif [ "$(fastfetch --config "$HOME/.config/fastfetch/config.jsonc" --pipe --logo none 2>/dev/null | grep -c .)" -ge 6 ]; then
    ok "fastfetch config parses and fills the banner"
  else
    err "fastfetch config parses but prints almost nothing (mistyped module name?)"
    fails=$((fails+1))
  fi
fi
bash -c '. "$HOME/.config/shell/greeting.sh"; type -t fetch' 2>/dev/null | grep -q function \
  && ok "'fetch' available in the shell" || { err "'fetch' NOT defined by greeting.sh"; fails=$((fails+1)); }
# Does a new terminal really print it? Compare a real login+interactive shell
# with the same shell greeting-suppressed; the size difference IS the banner,
# whichever backend drew it. ALTER_GREETED has to be cleared first: run from a
# terminal that already greeted, verify.sh would inherit the marker and see
# nothing (see README "Gotchas").
if have script; then
  _on=$(env -u ALTER_GREETED script -qec 'bash -lic true' /dev/null 2>/dev/null | wc -c)
  _off=$(env -u ALTER_GREETED ALTER_NO_GREETING=1 script -qec 'bash -lic true' /dev/null 2>/dev/null | wc -c)
  if [ "${_on:-0}" -gt "${_off:-0}" ]; then
    ok "new terminals greet ($(( _on - _off )) bytes of banner)"
  else
    err "a login shell prints no banner -- is the greeting hook in ~/.bashrc?"
    say  "    grep -n 'shell/greeting.sh' ~/.bashrc"
    fails=$((fails+1))
  fi
fi

hdr "Hotkey reference"
# docs/hotkeys.txt is what `keys` prints. It has a hard shape (CLAUDE.md,
# "Rule: docs/hotkeys.txt"): a fixed height, one blank border line top and
# bottom, nothing but hotkeys and tool commands, and a line for every tool
# alter installs. The numbers are the rule; the checks below are the rule made
# mechanical, so a stale or padded file fails here instead of at 2am.
HK="$ALTER_ROOT/docs/hotkeys.txt"; HK_MAX_LINES=50; HK_MAX_COLS=72
if [ ! -s "$HK" ]; then
  err "docs/hotkeys.txt MISSING or empty -- 'keys' prints nothing"; fails=$((fails+1))
else
  _n=$(grep -c '' "$HK")
  [ "$_n" -le "$HK_MAX_LINES" ] && ok "hotkeys.txt is $_n lines (max $HK_MAX_LINES)" \
    || { err "hotkeys.txt is $_n lines; max is $HK_MAX_LINES -- drop or merge a line"; fails=$((fails+1)); }
  _w=$(awk '{ if (length($0) > m) m = length($0) } END { print m+0 }' "$HK")
  [ "$_w" -le "$HK_MAX_COLS" ] && ok "hotkeys.txt widest line is $_w cols (max $HK_MAX_COLS)" \
    || { err "hotkeys.txt has a $_w-col line; max is $HK_MAX_COLS"; fails=$((fails+1)); }
  # Border: exactly one blank line first and last, none anywhere else.
  [ -z "$(sed -n '1p' "$HK")" ] && [ -z "$(sed -n '$p' "$HK")" ] && ok "hotkeys.txt: blank border line above and below" \
    || { err "hotkeys.txt: first and last line must each be blank"; fails=$((fails+1)); }
  # Between the borders every line is a section header (" NAME") or an entry:
  # key or command at col 4, description at col 27, nothing else.
  _bad=$(awk -v last="$_n" 'NR > 1 && NR < last && !/^ [A-Z][A-Z ()]*$/ && !/^   [^ ].{21} [^ ]/ { printf "    %d: %s\n", NR, $0 }' "$HK")
  [ -z "$_bad" ] && ok "hotkeys.txt: every line is a header or a key/description pair" \
    || { err "hotkeys.txt lines that are neither a header nor key@4/description@27:"; printf '%s\n' "$_bad" >&2; fails=$((fails+1)); }
  # Rationale, history and stock-vs-repo comparison belong in README, not here.
  _bad=$(grep -nE '\[stock\]|\bwas:|\(was |default|instead of|replaces' "$HK")
  [ -z "$_bad" ] && ok "hotkeys.txt: no history or comparison text" \
    || { err "hotkeys.txt carries history/comparison text (README owns that):"; printf '%s\n' "$_bad" | sed 's/^/    /' >&2; fails=$((fails+1)); }
  # Every tool alter installs has at least one line. Left side: the tool as
  # named in 00-packages.sh / 05-starship.sh / 40-extensions.sh; right side: the pattern that
  # proves its line exists. Add a pair here when you add a tool.
  _miss=""
  for pair in 'rofi:rofi' 'PaperWM:PAPERWM' 'Clipboard Indicator:clipboard' 'ghostty:GHOSTTY' \
              'fzf:(fzf)' 'zoxide:(zoxide)' 'eza:(eza)' 'bat:^   bat ' 'fd-find:^   fd ' \
              'ripgrep:^   rg ' 'git-delta:delta' 'gh:^   gh ' 'fastfetch:(fastfetch)' \
              'starship:^   starship ' 'keys:^   keys '; do
    grep -qE -- "${pair#*:}" "$HK" || _miss="$_miss ${pair%%:*}"
  done
  [ -z "$_miss" ] && ok "hotkeys.txt: every alter tool has a line" \
    || { err "hotkeys.txt has no line for:$_miss"; fails=$((fails+1)); }
fi

hdr "Result"
if [ "$fails" -eq 0 ]; then ok "all hard checks passed"; else err "$fails hard failure(s)"; fi
exit "$fails"
