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
# Pick the auth method up front. Falling back after a failure would re-run a
# command that failed for its own reasons, with its error hidden.
# `env` carries DEBIAN_FRONTEND through: sudo's env_reset drops it otherwise.
sudo_() {
  if sudo -n true 2>/dev/null || [ -z "${SUDO_ASKPASS:-}" ]; then run sudo env DEBIAN_FRONTEND=noninteractive "$@"
  else run sudo -A env DEBIAN_FRONTEND=noninteractive "$@"; fi
}
installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }

missing=()
for p in "${APT_PKGS[@]}"; do installed "$p" || missing+=("$p"); done

if [ ${#missing[@]} -eq 0 ]; then
  skip "all CLI packages already installed"
else
  say "  installing: ${missing[*]}"
  sudo_ apt-get update -qq || warn "apt-get update failed; installing from the existing package lists"
  if sudo_ apt-get install -y -qq "${missing[@]}"; then ok "installed ${missing[*]}"
  else err "apt-get install failed for: ${missing[*]}"; fi
fi

# ---- Ghostty ----
if have ghostty; then
  skip "ghostty already installed ($(ghostty --version 2>/dev/null | head -1))"
elif [ "${ALTER_SKIP_GHOSTTY:-0}" = 1 ]; then
  skip "ghostty skipped (ALTER_SKIP_GHOSTTY=1)"
elif apt-cache policy ghostty 2>/dev/null | grep -q 'Candidate: [0-9]'; then
  say "  ghostty available from configured repos"
  sudo_ apt-get install -y -qq ghostty && ok "installed ghostty" || err "ghostty install failed"
elif [ "$(os_id)" = ubuntu ]; then
  warn "ghostty is not in Ubuntu repos before 26.04; adding third-party PPA:"
  say  "    $GHOSTTY_PPA"
  say  "  Set ALTER_SKIP_GHOSTTY=1 to skip if your IT policy disallows PPAs."
  sudo_ add-apt-repository -y "$GHOSTTY_PPA"
  sudo_ apt-get update -qq
  sudo_ apt-get install -y -qq ghostty && ok "installed ghostty" || err "ghostty install failed"
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
  sudo_ apt-get install -y -qq fastfetch && ok "installed fastfetch" || warn "fastfetch install failed; the greeting uses its plain banner"
elif [ "$(os_id)" = ubuntu ]; then
  warn "fastfetch is not in Ubuntu repos before 24.10; adding third-party PPA:"
  say  "    $FASTFETCH_PPA"
  say  "  Set ALTER_SKIP_FASTFETCH=1 to skip -- the greeting degrades to a plain banner."
  sudo_ add-apt-repository -y "$FASTFETCH_PPA"
  sudo_ apt-get update -qq
  sudo_ apt-get install -y -qq fastfetch && ok "installed fastfetch" || warn "fastfetch install failed; the greeting uses its plain banner"
else
  warn "no fastfetch package source for $(os_id); see https://github.com/fastfetch-cli/fastfetch#installation"
fi
