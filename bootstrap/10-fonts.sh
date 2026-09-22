#!/usr/bin/env bash
# JetBrainsMono Nerd Font, user-local. No root required.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
WANT=(
  JetBrainsMonoNerdFont-Regular.ttf JetBrainsMonoNerdFont-Bold.ttf
  JetBrainsMonoNerdFont-Italic.ttf  JetBrainsMonoNerdFont-BoldItalic.ttf
  JetBrainsMonoNerdFontMono-Regular.ttf JetBrainsMonoNerdFontMono-Bold.ttf
  JetBrainsMonoNerdFontMono-Italic.ttf  JetBrainsMonoNerdFontMono-BoldItalic.ttf
)

hdr "Fonts"

if fc-list : family 2>/dev/null | grep -F 'JetBrainsMono Nerd Font' >/dev/null; then
  skip "JetBrainsMono Nerd Font already installed"
  return 0 2>/dev/null || exit 0
fi

have curl  || { err "curl not found"; return 1 2>/dev/null || exit 1; }
have unzip || { err "unzip not found (apt install unzip)"; return 1 2>/dev/null || exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN EXIT
say "  downloading (~128 MB, extracting 8 files)…"
run curl -fL --retry 2 --connect-timeout 20 -o "$tmp/jb.zip" "$URL" || { err "download failed"; return 1 2>/dev/null || exit 1; }
run mkdir -p "$FONT_DIR"
runq unzip -o -j "$tmp/jb.zip" "${WANT[@]}" -d "$FONT_DIR" || { err "unzip failed (release renamed its files?)"; return 1 2>/dev/null || exit 1; }
runq fc-cache -f "$FONT_DIR"
[ "$DRY_RUN" = 1 ] && { return 0 2>/dev/null || exit 0; }   # nothing was downloaded to check
fc-list : family 2>/dev/null | grep -F 'JetBrainsMono Nerd Font' >/dev/null \
  && ok "JetBrainsMono Nerd Font installed" || warn "font cache did not pick it up yet"
