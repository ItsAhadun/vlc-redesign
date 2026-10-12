#!/usr/bin/env bash
# Launch the real VLC Qt interface headless (Xvfb), take a PNG screenshot, quit.
#
# usage: screenshot.sh [options] <out.png> [media-file-or-mrl] [-- extra vlc args...]
#
# options:
#   --size WxH         screen + window size (default 1920x1080)
#   --theme T          light | dark | system  (default light). Sets the
#                      MainWindow/color-scheme-index Qt setting (1=Day, 2=Night,
#                      0=System) in the throw-away profile.
#   --scale F          interface scale factor (VLC option --qt-interface-scale)
#   --wait S           seconds to wait after the window appears before
#                      capturing (default 6; 8 when a media file is given)
#   --profile DIR      profile template to copy (default: $VLC_PROFILE, i.e.
#                      /opt/vlc-profile = seeded media library with the sample
#                      media from setup.sh). "--profile none" = empty profile
#                      (no media library content, first-run wizard skipped)
#   --keep-profile DIR keep the run's profile (config/data/cache) in DIR
#   --playing          do not pause: capture while the media plays (default
#                      for media is --start-paused, so the player view shows
#                      a stable first frame with controls visible)
#   --at SECONDS       start the media at this time (still paused)
#   --compositor C     VLC Qt compositor: "dummy" (default) or "x11"/"auto".
#                      Under Xvfb the X11 compositor (which embeds the video
#                      in the main window) draws the raw video over the whole
#                      interface, so by default the dummy compositor is used:
#                      the UI is rendered completely, the player view shows
#                      its "video in external window" placeholder card and
#                      the video goes to a separate window kept below the UI.
#   --do "ACTION"      run an action after the UI is up, before capture; may be
#                      repeated, run in order. ACTION is one of
#                        click X Y        left click at screen coordinates
#                        dclick X Y       double click
#                        move X Y         move the pointer (hover states)
#                        wheel X Y DIR [N] mouse wheel at X Y, DIR = up|down|
#                                         left|right, N notches (default 1)
#                        key KEYS         xdotool key, e.g. "key ctrl+l" (to
#                                         the main window, focused first)
#                        type TEXT        type text (to the main window)
#                        fkey KEYS        key / type to the currently focused
#                        ftype TEXT       window (e.g. the settings window)
#                        sleep S          wait S seconds
#                        shot FILE.png    take an extra screenshot now
#   --keep-windows     keep the other top-level windows (settings window,
#                      dialogs) on screen, above the main window; by default
#                      only the main window is captured. The video window of
#                      the dummy compositor is hidden in both cases.
#   --log FILE         where to write the VLC log (default: <out>.log)
#   --no-qml-warnings  don't print QML warnings found in the log
#
# Examples:
#   screenshot.sh /tmp/home.png
#   screenshot.sh --theme dark /tmp/home-dark.png
#   screenshot.sh /tmp/player.png /opt/vlc-media/test-720p.mp4
#   screenshot.sh --do "click 60 92" --do "sleep 2" /tmp/video.png  # Video tab
#   screenshot.sh --size 1280x720 /tmp/small.png -- --qt-minimal-view
#   screenshot.sh --keep-windows --do "key ctrl+p" --do "sleep 2" /tmp/settings.png
#
# The script prints the QML warnings/errors (qrc:/... lines) from the VLC log;
# they are the runtime counterpart of qml-check.sh. Exit code is non-zero if
# VLC did not show a window.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

size=1920x1080
theme=light
scale=""
wait_s=""
profile="${VLC_PROFILE:-/opt/vlc-profile}"
keep_profile=""
playing=0
start_at=""
compositor=dummy
actions=()
logfile=""
show_qml=1
keep_windows=0
pos=()
extra=()
while [ $# -gt 0 ]; do
    case "$1" in
        --size) size="$2"; shift ;;
        --theme) theme="$2"; shift ;;
        --scale) scale="$2"; shift ;;
        --wait) wait_s="$2"; shift ;;
        --profile) profile="$2"; shift ;;
        --keep-profile) keep_profile="$2"; shift ;;
        --playing) playing=1 ;;
        --at) start_at="$2"; shift ;;
        --compositor) compositor="$2"; shift ;;
        --do) actions+=("$2"); shift ;;
        --log) logfile="$2"; shift ;;
        --no-qml-warnings) show_qml=0 ;;
        --keep-windows) keep_windows=1 ;;
        -h|--help) sed -n '2,/^set -e/{/^#/p}' "$0"; exit 0 ;;
        --) shift; extra=("$@"); break ;;
        *) pos+=("$1") ;;
    esac
    shift
done
[ ${#pos[@]} -ge 1 ] || { sed -n '2,/^set -e/{/^#/p}' "$0"; exit 2; }
out="$(realpath -m "${pos[0]}")"
media="${pos[1]:-}"
[ -n "$logfile" ] || logfile="${out%.png}.log"
W="${size%x*}"; H="${size#*x}"
case "$theme" in
    light|day) scheme=1 ;; dark|night) scheme=2 ;; system) scheme=0 ;;
    *) die "unknown theme '$theme' (light|dark|system)" ;;
esac
[ -n "$wait_s" ] || { [ -n "$media" ] && wait_s=8 || wait_s=6; }

require_build
VLC_BIN="$VLC_BUILD/bin/vlc-static"
[ -x "$VLC_BIN" ] || die "$VLC_BIN not built (run build-qt.sh or ninja -C $VLC_BUILD)"
mkdir -p "$(dirname "$out")"

# --- throw-away profile ---------------------------------------------------------
run="$(mktemp -d /tmp/vlc-shot.XXXXXX)"
xvfb_pid=""; vlc_pid=""
cleanup() {
    [ -n "$vlc_pid" ] && { kill -9 "$vlc_pid"; wait "$vlc_pid"; } 2>/dev/null || true
    [ -n "$xvfb_pid" ] && kill "$xvfb_pid" 2>/dev/null || true
    if [ -n "$keep_profile" ]; then
        mkdir -p "$keep_profile" && cp -a "$run/p/." "$keep_profile/" 2>/dev/null || true
    fi
    rm -rf "$run"
}
trap cleanup EXIT
mkdir -p "$run/p"
if [ "$profile" != none ] && [ -d "$profile" ]; then
    cp -a "$profile/." "$run/p/"
elif [ "$profile" != none ]; then
    echo "warning: profile template $profile not found, using an empty profile (run setup.sh --profile)" >&2
fi
P="$run/p"
mkdir -p "$P/home" "$P/config/vlc" "$P/data" "$P/cache" "$P/run"
chmod 700 "$P/run"
rm -rf "$P/cache/vlc/qmlcache"
conf="$P/config/vlc/vlc-qt-interface.conf"
python3 -I - "$conf" "$scheme" <<'EOF'
import configparser, sys
path, scheme = sys.argv[1], sys.argv[2]
cp = configparser.RawConfigParser(strict=False, interpolation=None)
cp.optionxform = str
try:
    cp.read(path, encoding="utf-8-sig")
except Exception:
    pass
if not cp.has_section("MainWindow"):
    cp.add_section("MainWindow")
cp.set("MainWindow", "color-scheme-index", scheme)
with open(path, "w") as f:
    cp.write(f, space_around_delimiters=False)
EOF

export HOME="$P/home" XDG_CONFIG_HOME="$P/config" XDG_DATA_HOME="$P/data" \
       XDG_CACHE_HOME="$P/cache" XDG_RUNTIME_DIR="$P/run"
export QML_DISABLE_DISK_CACHE=1
unset WAYLAND_DISPLAY
export QT_QPA_PLATFORM=xcb

# --- X server -------------------------------------------------------------------
exec 5> "$run/display"
Xvfb -displayfd 5 -screen 0 "${W}x${H}x24" -nolisten tcp -noreset +extension GLX \
    > "$run/xvfb.log" 2>&1 &
xvfb_pid=$!
for _ in $(seq 50); do [ -s "$run/display" ] && break; sleep 0.1; done
[ -s "$run/display" ] || die "Xvfb did not start: $(cat "$run/xvfb.log")"
export DISPLAY=":$(head -1 "$run/display")"

# --- VLC ------------------------------------------------------------------------
vlcargs=(-I qt --no-qt-privacy-ask --no-metadata-network-access
         --aout=adummy --no-qt-system-tray --verbose=1 --qt-compositor="$compositor")
[ -n "$scale" ] && vlcargs+=(--qt-interface-scale="$scale")
if [ -n "$media" ]; then
    [ $playing = 1 ] || vlcargs+=(--start-paused)
    [ -n "$start_at" ] && vlcargs+=(--start-time="$start_at")
    [ -e "$media" ] && media="$(realpath "$media")"
fi
vlcargs+=("${extra[@]+"${extra[@]}"}")
[ -n "$media" ] && vlcargs+=("$media")

"$VLC_BIN" "${vlcargs[@]}" > "$logfile" 2>&1 &
vlc_pid=$!

main_window() {
    # The Qt main window: largest mapped top-level window with WM_CLASS
    # "vlc","vlc" (the video output window is "vlc","Vlc" / role vlc-video).
    xwininfo -root -children 2>/dev/null | awk '/^ +0x[0-9a-f]+ /{print $1}' |
    while read -r id; do
        st="$(xwininfo -id "$id" 2>/dev/null)" || continue
        grep -q 'IsViewable' <<<"$st" || continue
        props="$(xprop -id "$id" WM_CLASS WM_WINDOW_ROLE WM_NAME 2>/dev/null)" || continue
        grep -q 'WM_CLASS(STRING) = "vlc", "vlc"' <<<"$props" || continue
        grep -q 'vlc-video' <<<"$props" && continue
        grep -q 'WM_NAME(STRING) = "Welcome' <<<"$props" && continue
        w="$(sed -n 's/^ *Width: //p' <<<"$st")"; h="$(sed -n 's/^ *Height: //p' <<<"$st")"
        echo "$((w*h)) $id"
    done | sort -nr | awk 'NR==1{print $2}'
}
# wait for the main window (the largest viewable toplevel named "VLC media player")
win=""
for _ in $(seq 150); do
    kill -0 "$vlc_pid" 2>/dev/null || break
    win="$(main_window || true)"
    [ -n "$win" ] && break
    sleep 0.2
done
if [ -z "$win" ]; then
    echo "error: VLC window did not appear; log tail:" >&2
    tail -30 "$logfile" >&2
    exit 1
fi
# fill the virtual screen (there is no window manager)
xdotool windowmove "$win" 0 0 windowsize "$win" "$W" "$H" 2>/dev/null || true
xdotool mousemove "$((W-1))" "$((H-1))" 2>/dev/null || true
sleep "$wait_s"

for a in "${actions[@]+"${actions[@]}"}"; do
    read -r verb rest <<<"$a"
    case "$verb" in
        click)  read -r x y <<<"$rest"; xdotool mousemove "$x" "$y" click 1 ;;
        dclick) read -r x y <<<"$rest"; xdotool mousemove "$x" "$y" click --repeat 2 1 ;;
        move)   read -r x y <<<"$rest"; xdotool mousemove "$x" "$y" ;;
        wheel)  read -r x y dir n <<<"$rest"
                case "$dir" in up) b=4 ;; down) b=5 ;; left) b=6 ;; right) b=7 ;;
                    *) echo "warning: bad wheel direction '$dir'" >&2; continue ;; esac
                xdotool mousemove "$x" "$y" click --repeat "${n:-1}" --delay 50 "$b" ;;
        key)    xdotool windowfocus "$win" 2>/dev/null || true; xdotool key $rest ;;
        type)   xdotool windowfocus "$win" 2>/dev/null || true; xdotool type -- "$rest" ;;
        fkey)   xdotool key $rest ;;
        ftype)  xdotool type -- "$rest" ;;
        sleep)  sleep "$rest" ;;
        shot)   import -window root "$(realpath -m "$rest")"; echo "extra screenshot: $rest" ;;
        *) echo "warning: unknown action '$a'" >&2 ;;
    esac
    sleep 0.3
done
[ ${#actions[@]} -gt 0 ] && sleep 1

kill -0 "$vlc_pid" 2>/dev/null || { echo "error: VLC exited early; log tail:" >&2; tail -30 "$logfile" >&2; exit 1; }
# Keep only the main window on screen: with the dummy compositor the video is
# in a separate top-level window whose stacking order is random.
# --keep-windows: hide only the video window, keep the other windows (settings
# window, dialogs) above the main window.
others=()
if [ "$compositor" = dummy ] || [ $keep_windows = 1 ]; then
    for id in $(xwininfo -root -children 2>/dev/null | awk '/^ +0x[0-9a-f]+ /{print $1}'); do
        [ "$((id))" = "$((win))" ] && continue
        xwininfo -id "$id" 2>/dev/null | grep -q IsViewable || continue
        if [ $keep_windows = 1 ]; then
            props="$(xprop -id "$id" WM_CLASS WM_WINDOW_ROLE 2>/dev/null)" || continue
            if ! grep -q 'vlc-video\|WM_CLASS(STRING) = "vlc", "Vlc"' <<<"$props"; then
                others+=("$id")
                continue
            fi
            [ "$compositor" = dummy ] || continue
        fi
        xdotool windowunmap "$id" 2>/dev/null || true
    done
fi
xdotool windowraise "$win" 2>/dev/null || true
for id in "${others[@]+"${others[@]}"}"; do xdotool windowraise "$id" 2>/dev/null || true; done
sleep 0.5
import -window root "$out"
echo "screenshot: $out (${W}x${H}, theme=$theme${media:+, media=$media})"
echo "vlc log:    $logfile"

if [ $show_qml = 1 ]; then
    q="$(grep -E 'qrc:/|\.qml:[0-9]+|QML |qml:' "$logfile" \
         | sed -E 's/^\[[0-9a-f]+\] (\[qt\] )?qt generic ([a-z]+): \([^)]*\) /\2: /' \
         | sort | uniq -c | sort -rn || true)"
    if [ -n "$q" ]; then
        echo "--- QML runtime warnings/errors (count, message) ---"
        echo "$q" | head -60
    fi
fi
