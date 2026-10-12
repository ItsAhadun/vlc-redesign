#!/usr/bin/env bash
# Incremental rebuild of the Qt interface plugin (and what it depends on).
#
# usage: build-qt.sh [--all] [extra ninja args]
#   --all   build every target of the build dir (needed once for a fresh build
#           dir, e.g. a new worktree: the vlc binary + all other plugins)
#
# QML/JS/SVG edits only re-run rcc and relink libqt_plugin.so (~10-30 s).
# C++ edits recompile the touched files. Adding a new QML file also requires
# listing it in modules/gui/qt/meson.build (ninja re-runs meson by itself).
# If the build dir doesn't exist yet, it is configured first (setup.sh
# --configure-only), so this also works from a fresh git worktree.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

all=0
if [ "${1:-}" = "--all" ]; then all=1; shift; fi

if [ ! -f "$VLC_BUILD/build.ninja" ]; then
    echo "build-qt: no build dir at $VLC_BUILD, configuring it" >&2
    "$_tools_dir/setup.sh" --configure-only
    all=1
fi

start=$(date +%s)
if [ $all = 1 ] || [ ! -x "$VLC_BUILD/bin/vlc-static" ]; then
    ninja -C "$VLC_BUILD" "$@"
else
    targets=(modules/libqt_plugin.so)
    # optional helper plugins, only if this build has them
    for t in modules/libqt_x11_plugin.so modules/libqt_wayland_plugin.so; do
        grep -q "^build $t:" "$VLC_BUILD/build.ninja" && targets+=("$t")
    done
    ninja -C "$VLC_BUILD" "$@" "${targets[@]}"
fi
echo "build-qt: done in $(( $(date +%s) - start ))s ($VLC_BUILD)"
