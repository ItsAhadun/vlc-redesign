#!/usr/bin/env bash
# Create the VLC profile template used by screenshot.sh: a config + media
# library database that already indexed the sample media in $VLC_MEDIA
# (Videos/ and Music/), so library views have content.
#
# usage: seed-profile.sh [profile-dir]   (default: $VLC_PROFILE or /opt/vlc-profile)
#
# It runs VLC once under Xvfb with XDG_VIDEOS_DIR/XDG_MUSIC_DIR pointing at the
# sample media, walks through the first-run wizard (which adds those two
# folders to the media library), waits for indexing + thumbnails and quits.
# The resulting profile uses the default first-run choices (modern layout,
# client-side decorations, system color scheme).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
require_build

dest="${1:-${VLC_PROFILE:-/opt/vlc-profile}}"
VLC_BIN="$VLC_BUILD/bin/vlc-static"
[ -d "$VLC_MEDIA/Videos" ] || die "$VLC_MEDIA/Videos missing (run setup.sh --media)"

run="$(mktemp -d /tmp/vlc-seed.XXXXXX)"
xvfb_pid=""; vlc_pid=""
cleanup() {
    [ -n "$vlc_pid" ] && kill -9 "$vlc_pid" 2>/dev/null || true
    [ -n "$xvfb_pid" ] && kill "$xvfb_pid" 2>/dev/null || true
    rm -rf "$run"
}
trap cleanup EXIT
P="$run/p"
mkdir -p "$P/home" "$P/config" "$P/data" "$P/cache" "$P/run"; chmod 700 "$P/run"
printf 'XDG_VIDEOS_DIR="%s/Videos"\nXDG_MUSIC_DIR="%s/Music"\n' "$VLC_MEDIA" "$VLC_MEDIA" > "$P/config/user-dirs.dirs"
export HOME="$P/home" XDG_CONFIG_HOME="$P/config" XDG_DATA_HOME="$P/data" \
       XDG_CACHE_HOME="$P/cache" XDG_RUNTIME_DIR="$P/run" QT_QPA_PLATFORM=xcb
unset WAYLAND_DISPLAY

exec 5> "$run/display"
Xvfb -displayfd 5 -screen 0 1920x1080x24 -nolisten tcp -noreset > "$run/xvfb.log" 2>&1 &
xvfb_pid=$!
for _ in $(seq 50); do [ -s "$run/display" ] && break; sleep 0.1; done
export DISPLAY=":$(head -1 "$run/display")"

"$VLC_BIN" -I qt --qt-privacy-ask --no-metadata-network-access --aout=adummy \
    --no-qt-system-tray > "$run/vlc.log" 2>&1 &
vlc_pid=$!

wiz=""
for _ in $(seq 100); do
    wiz="$(xdotool search --onlyvisible --name '^Welcome' 2>/dev/null | head -1 || true)"
    [ -n "$wiz" ] && break; sleep 0.2
done
[ -n "$wiz" ] || { tail -20 "$run/vlc.log" >&2; die "first-run wizard did not show up"; }
sleep 2
# Press the default button (Next >, ..., Finish) until the wizard is gone.
for _ in $(seq 10); do
    xdotool search --onlyvisible --name '^Welcome' >/dev/null 2>&1 || break
    eval "$(xdotool getwindowgeometry --shell "$wiz")"
    # "Next/Finish" sits in the bottom-right corner of the QWizard
    xdotool mousemove "$((X + WIDTH - 52))" "$((Y + HEIGHT - 23))" click 1
    sleep 1.5
done
xdotool search --onlyvisible --name '^Welcome' >/dev/null 2>&1 && die "could not finish the first-run wizard"

# wait for the library to index everything and generate thumbnails
nfiles="$(find "$VLC_MEDIA/Videos" "$VLC_MEDIA/Music" -type f \( -name '*.mp4' -o -name '*.mp3' -o -name '*.mkv' -o -name '*.ogg' \) | wc -l)"
db="$P/data/vlc/ml/ml.db"
prev=""
for i in $(seq 90); do
    sleep 1
    [ -f "$db" ] || continue
    st="$(python3 -I - "$db" <<'EOF' 2>/dev/null || true
import sqlite3, sys
c = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
m = c.execute("select count(*) from Media").fetchone()[0]
try:
    t = c.execute("select count(*) from Thumbnail").fetchone()[0]
except Exception:
    t = -1
print(m, t)
EOF
)"
    set -- $st
    if [ "${1:-0}" -ge "$nfiles" ] && [ "$st" = "$prev" ] && [ $i -gt 10 ]; then break; fi
    prev="$st"
done
echo "media library: ${1:-0} media indexed (${nfiles} sample files), thumbnails: ${2:-?}"
sleep 3
{ kill "$vlc_pid"
  for _ in $(seq 30); do kill -0 "$vlc_pid" || break; sleep 0.2; done
  kill -9 "$vlc_pid"; wait "$vlc_pid"; } 2>/dev/null || true
vlc_pid=""

rm -rf "$P/cache/vlc/qmlcache" "$P/run"
rm -rf "$dest"; mkdir -p "$(dirname "$dest")"
cp -a "$P" "$dest"
echo "profile template written to $dest"
