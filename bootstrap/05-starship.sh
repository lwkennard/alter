#!/usr/bin/env bash
# Install the starship prompt (https://starship.rs) as a user-local binary.
#
# starship is not in the Ubuntu 24.04 repos and there is no PPA, so this stage
# takes the release tarball straight from GitHub, checks it against the
# published sha256 and drops the single binary into ~/.local/bin -- no root,
# no `curl | sh`, no cargo. The shell hook lives in config/shell/devtools.sh
# and the prompt layout in config/starship/starship.toml (linked by
# 30-dotfiles.sh), so this file only has to get the binary onto the machine.
#
#   ALTER_SKIP_STARSHIP=1        skip entirely (the stock bash prompt stays)
#   ALTER_STARSHIP_VERSION=v1.x  pin a release; default is the latest
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

hdr "Starship prompt"

STARSHIP_BIN="$HOME/.local/bin/starship"
STARSHIP_REPO="https://github.com/starship/starship"

if have starship; then
  skip "starship already installed ($(starship --version 2>/dev/null | head -1) at $(command -v starship))"
  return 0 2>/dev/null || exit 0
elif [ "${ALTER_SKIP_STARSHIP:-0}" = 1 ]; then
  skip "starship skipped (ALTER_SKIP_STARSHIP=1); the stock prompt stays"
  return 0 2>/dev/null || exit 0
fi

for t in curl tar sha256sum install; do
  have "$t" || { warn "$t not found; cannot fetch starship (install it or set ALTER_SKIP_STARSHIP=1)"; return 0 2>/dev/null || exit 0; }
done

# Upstream ships static musl builds for every Linux arch, so use those and
# sidestep the glibc-version question on an older or non-Ubuntu box.
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)  target=x86_64-unknown-linux-musl ;;
  Linux-aarch64) target=aarch64-unknown-linux-musl ;;
  Linux-armv7l)  target=arm-unknown-linux-musleabihf ;;
  Linux-i686)    target=i686-unknown-linux-musl ;;
  *) warn "no prebuilt starship for $(uname -s)/$(uname -m); see $STARSHIP_REPO#-installation"
     return 0 2>/dev/null || exit 0 ;;
esac

ver="${ALTER_STARSHIP_VERSION:-latest}"
case "$ver" in
  latest) url="$STARSHIP_REPO/releases/latest/download" ;;
  v*)     url="$STARSHIP_REPO/releases/download/$ver" ;;
  *)      url="$STARSHIP_REPO/releases/download/v$ver" ;;
esac
asset="starship-$target.tar.gz"
say "  fetching $ver $asset -> $STARSHIP_BIN"

if [ "$DRY_RUN" = 1 ]; then
  printf '  %s[dry-run]%s download %s/%s (+ .sha256), verify, install to %s\n' "$c_dim" "$c_off" "$url" "$asset" "$STARSHIP_BIN"
else
  tmp=$(mktemp -d) || { err "mktemp failed"; return 1 2>/dev/null || exit 1; }
  if ! curl -fsSL --retry 2 -o "$tmp/$asset"        "$url/$asset" ||
     ! curl -fsSL --retry 2 -o "$tmp/$asset.sha256" "$url/$asset.sha256"; then
    err "download failed: $url/$asset"
    say "    offline? Re-run './install.sh starship' later; nothing else depends on it."
  # The .sha256 asset is the bare hex digest, no filename after it.
  elif [ "$(sha256sum "$tmp/$asset" | cut -d' ' -f1)" != "$(tr -d '[:space:]' <"$tmp/$asset.sha256")" ]; then
    err "sha256 mismatch for $asset -- not installing"
  elif ! tar -xzf "$tmp/$asset" -C "$tmp" starship; then
    err "could not extract 'starship' from $asset"
  else
    mkdir -p "$(dirname "$STARSHIP_BIN")"
    install -m 755 "$tmp/starship" "$STARSHIP_BIN" &&
      ok "installed $("$STARSHIP_BIN" --version 2>/dev/null | head -1) -> $STARSHIP_BIN"
  fi
  rm -rf "$tmp"
fi
# ~/.local/bin may not be on PATH yet in the shell that ran this (Ubuntu's
# ~/.profile adds it at login only if the directory already existed). Nothing
# to do here: lib.sh adds it for every stage and devtools.sh for every
# interactive shell, so the next terminal has the prompt regardless.
