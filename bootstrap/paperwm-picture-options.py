#!/usr/bin/env python3
"""Make PaperWM honour org.gnome.desktop.background picture-options.

PaperWM draws its own per-monitor background for every space and hardcodes
GDesktopEnums.BackgroundStyle.ZOOM, so every value of picture-options --
spanned, centered, stretched -- is a no-op while PaperWM is active.

Usage: pwmpatch.py apply|revert|check <tiling.js>
Exit: 0 patched/ok, 1 not patched, 2 cannot patch (unknown file contents).
"""
import sys, os, shutil

MARK = 'alter:picture-options'

SIG_OLD = (
    '        this.signals.connect(backgroundSettings, "changed::picture-uri-dark", '
    'this.updateBackground.bind(this));\n'
)
SIG_NEW = SIG_OLD + (
    '        // alter:picture-options -- upstream watches picture-uri but not the\n'
    '        // style key, so a change to picture-options would not repaint until\n'
    '        // something else forced a workspace refresh.\n'
    '        this.signals.connect(backgroundSettings, "changed::picture-options", '
    'this.updateBackground.bind(this));\n'
)

STYLE_OLD = """        let useDefault = gsettings.get_boolean('use-default-background');
        if (!path && useDefault) {
"""
STYLE_NEW = """        let useDefault = gsettings.get_boolean('use-default-background');
        // alter:picture-options -- a per-space image is an explicit override and
        // keeps upstream's hardcoded ZOOM (the same rule background.js applies to
        // _overrideImage). Only the system wallpaper follows the system's own
        // picture-options, which is what lets 'spanned' cross both monitors.
        let style = GDesktopEnums.BackgroundStyle.ZOOM;
        if (!path && useDefault) {
            style = backgroundSettings.get_enum('picture-options');
"""

USE_OLD = '            style: GDesktopEnums.BackgroundStyle.ZOOM,\n'
USE_NEW = '            style, // alter:picture-options\n'

EDITS = [(SIG_OLD, SIG_NEW), (STYLE_OLD, STYLE_NEW), (USE_OLD, USE_NEW)]


def main():
    action, path = sys.argv[1], sys.argv[2]
    orig = path + '.alter-orig'
    src = open(path, encoding='utf-8').read()

    if action == 'check':
        return 0 if MARK in src else 1

    if action == 'revert':
        if not os.path.exists(orig):
            print('no .alter-orig backup; leaving %s alone' % path)
            return 1
        shutil.copymode(path, orig)
        os.replace(orig, path)
        print('restored %s from .alter-orig' % path)
        return 0

    if MARK in src:
        print('already patched')
        return 0

    for old, _ in EDITS:
        n = src.count(old)
        if n != 1:
            print('anchor appears %d times, expected 1 -- refusing to patch:\n%s'
                  % (n, old.strip()[:90]))
            return 2

    out = src
    for old, new in EDITS:
        out = out.replace(old, new, 1)

    if not os.path.exists(orig):
        shutil.copy2(path, orig)
    tmp = path + '.alter-tmp'
    with open(tmp, 'w', encoding='utf-8') as fh:
        fh.write(out)
    shutil.copymode(path, tmp)
    os.replace(tmp, path)
    print('patched %s (backup at %s)' % (path, orig))
    return 0


sys.exit(main())
