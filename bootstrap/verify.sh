#!/usr/bin/env bash
# Check that the setup actually took. Exits non-zero on hard failures.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
fails=0

hdr "Binaries"
for c in rofi fzf zoxide fdfind batcat eza delta gh ghostty; do
  if have "$c"; then ok "$c -> $(command -v "$c")"; else err "$c MISSING"; fails=$((fails+1)); fi
done

hdr "Font"
fc-list : family 2>/dev/null | grep -F 'JetBrainsMono Nerd Font' >/dev/null \
  && ok "JetBrainsMono Nerd Font present" || { err "Nerd Font MISSING"; fails=$((fails+1)); }

hdr "Configs parse"
if have ghostty; then
  ghostty +validate-config --config-file="$HOME/.config/ghostty/config" >/dev/null 2>&1 \
    && ok "ghostty config valid" || { err "ghostty config INVALID"; fails=$((fails+1)); }
  # Split navigation is the one binding this repo moves off a Ghostty default,
  # so confirm all four directions actually landed.
  n=$(ghostty +list-keybinds 2>/dev/null | grep -c 'ctrl+shift+arrow_.*=goto_split:')
  [ "${n:-0}" = 4 ] && ok "Ctrl+Shift+arrows -> move between splits" \
    || { err "Ctrl+Shift+arrows split navigation: $n/4 bound"; fails=$((fails+1)); }
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

hdr "Shell integration"
# readline bindings only exist under a real pty, so allocate one
if have script; then
  out=$(script -qec 'bash -i -c "bind -X 2>/dev/null"' /dev/null 2>/dev/null | tr -d '\r')
  printf '%s' "$out" | grep -q '__fzf_history__'  && ok "Ctrl+R -> fzf history"     || { warn "Ctrl+R binding not detected"; }
  printf '%s' "$out" | grep -q 'fzf-file-widget'  && ok "Ctrl+T -> fzf file widget" || { warn "Ctrl+T binding not detected"; }
fi
bash -c '. "$HOME/.config/shell/devtools.sh"; type -t __zoxide_z' 2>/dev/null | grep -q function \
  && ok "zoxide initialised" || { err "zoxide NOT initialised"; fails=$((fails+1)); }

hdr "GNOME"
if is_gnome; then
  for i in 1 2 3 4; do
    v=$(gsettings get org.gnome.desktop.wm.keybindings "switch-to-workspace-$i" 2>/dev/null)
    [ "$v" = "['<Super>$i']" ] && ok "Super+$i -> workspace $i" || warn "Super+$i is $v"
  done
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

hdr "Result"
if [ "$fails" -eq 0 ]; then ok "all hard checks passed"; else err "$fails hard failure(s)"; fi
exit "$fails"
