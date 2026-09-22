#!/usr/bin/env bash
# Install the CLI layer and Ghostty. Debian/Ubuntu only; other distros are
# reported so you can install the equivalents by hand.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

APT_PKGS=(rofi fzf zoxide fd-find bat eza git-delta ripgrep gh)
GHOSTTY_PPA="ppa:mkasberg/ghostty-ubuntu"   # official repos only carry it from Ubuntu 26.04

hdr "Packages"

if ! is_debianish; then
  warn "not a Debian/Ubuntu system (ID=$(os_id)); install these yourself:"
  say  "    ${APT_PKGS[*]} ghostty fastfetch"
  return 0 2>/dev/null || exit 0
fi

# Use a GUI askpass when there's a display but no TTY (e.g. driven by a tool).
if [ -z "${SUDO_ASKPASS:-}" ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && have zenity; then
  export SUDO_ASKPASS="$ALTER_ROOT/bin/zenity-askpass"
fi
sudo_() { if sudo -n true 2>/dev/null; then run sudo "$@"; else run sudo -A "$@" 2>/dev/null || run sudo "$@"; fi; }

missing=()
for p in "${APT_PKGS[@]}"; do dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p"); done

if [ ${#missing[@]} -eq 0 ]; then
  skip "all CLI packages already installed"
else
  say "  installing: ${missing[*]}"
  sudo_ apt-get update -qq
  DEBIAN_FRONTEND=noninteractive sudo_ apt-get install -y -qq "${missing[@]}"
  ok "installed ${missing[*]}"
fi

# ---- Ghostty ----
if have ghostty; then
  skip "ghostty already installed ($(ghostty --version 2>/dev/null | head -1))"
elif [ "${ALTER_SKIP_GHOSTTY:-0}" = 1 ]; then
  skip "ghostty skipped (ALTER_SKIP_GHOSTTY=1)"
elif apt-cache policy ghostty 2>/dev/null | grep -q 'Candidate: [0-9]'; then
  say "  ghostty available from configured repos"
  DEBIAN_FRONTEND=noninteractive sudo_ apt-get install -y -qq ghostty && ok "installed ghostty"
elif [ "$(os_id)" = ubuntu ]; then
  warn "ghostty is not in Ubuntu repos before 26.04; adding third-party PPA:"
  say  "    $GHOSTTY_PPA"
  say  "  Set ALTER_SKIP_GHOSTTY=1 to skip if your IT policy disallows PPAs."
  sudo_ add-apt-repository -y "$GHOSTTY_PPA"
  sudo_ apt-get update -qq
  DEBIAN_FRONTEND=noninteractive sudo_ apt-get install -y -qq ghostty && ok "installed ghostty"
else
  warn "no ghostty package source for $(os_id); see https://ghostty.org/docs/install/binary"
fi

# ---- fastfetch ----
# Powers the new-terminal banner (config/shell/greeting.sh). Ubuntu carries it
# from 24.10; 24.04 has no candidate at all, hence the upstream PPA. Skipping
# it is not fatal -- greeting.sh falls back to a coreutils-only banner.
FASTFETCH_PPA="ppa:zhangsongcui3371/fastfetch"
if have fastfetch; then
  skip "fastfetch already installed ($(fastfetch --version 2>/dev/null | head -1))"
elif [ "${ALTER_SKIP_FASTFETCH:-0}" = 1 ]; then
  skip "fastfetch skipped (ALTER_SKIP_FASTFETCH=1)"
elif apt-cache policy fastfetch 2>/dev/null | grep -q 'Candidate: [0-9]'; then
  say "  fastfetch available from configured repos"
  DEBIAN_FRONTEND=noninteractive sudo_ apt-get install -y -qq fastfetch && ok "installed fastfetch"
elif [ "$(os_id)" = ubuntu ]; then
  warn "fastfetch is not in Ubuntu repos before 24.10; adding third-party PPA:"
  say  "    $FASTFETCH_PPA"
  say  "  Set ALTER_SKIP_FASTFETCH=1 to skip -- the greeting degrades to a plain banner."
  sudo_ add-apt-repository -y "$FASTFETCH_PPA"
  sudo_ apt-get update -qq
  DEBIAN_FRONTEND=noninteractive sudo_ apt-get install -y -qq fastfetch && ok "installed fastfetch"
else
  warn "no fastfetch package source for $(os_id); see https://github.com/fastfetch-cli/fastfetch#installation"
fi
