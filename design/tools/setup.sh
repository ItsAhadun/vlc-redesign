#!/usr/bin/env bash
# Recreate the local VLC Qt UI build/verification environment from scratch.
# Idempotent: every step is skipped when its result already exists.
#
# usage: setup.sh [options]
#   (no option)        everything: apt + pip + Qt + medialibrary + sample media
#                      + configure + full build + seeded profile
#   --configure-only   only (re)configure the meson build dir for VLC_SRC
#                      (deps must already be installed); used by build-qt.sh
#   --no-build         install deps + configure, but don't build
#   --reconfigure      wipe and reconfigure the build dir
#   --deps-only        only system deps, Qt, medialibrary, sample media
#   --profile          only (re)create the seeded profile template
#
# Env (see _common.sh): VLC_SRC, VLC_BUILD, VLC_QT_VERSION (6.8.3, same as the
# Windows contribs: contrib/src/main.mak), VLC_QT_DIR, VLC_DEPS, VLC_MEDIA,
# VLC_PROFILE.
#
# What it sets up:
#   /opt/qt/<ver>/gcc_64   Qt from aqtinstall (+qtshadertools, qt5compat,
#                          qtimageformats). Ubuntu 24.04 only has Qt 6.4.2.
#   /opt/vlc-deps          medialibrary 0.13.2 (same as contribs; Ubuntu only
#                          ships 0.12.3, VLC requires >= 0.13), built with
#                          -Dlibvlc=disabled like contrib does
#   /opt/vlc-media         generated sample videos + tagged mp3 albums
#   $VLC_BUILD             meson build, minimal feature set (see MESON_OPTS)
#   /opt/vlc-profile       VLC profile whose media library indexed /opt/vlc-media
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

mode=all
reconfigure=0
for a in "$@"; do
    case "$a" in
        --configure-only) mode=configure ;;
        --no-build) mode=nobuild ;;
        --deps-only) mode=deps ;;
        --profile) mode=profile ;;
        --reconfigure) reconfigure=1 ;;
        -h|--help) sed -n '2,/^set -e/{/^#/p}' "$0"; exit 0 ;;
        *) die "unknown option $a" ;;
    esac
done

: "${VLC_PROFILE:=/opt/vlc-profile}"
ML_VERSION=0.13.2

# Minimal feature set: Qt + medialibrary + what is needed to play/thumbnail
# common files. Notes:
#  - videolan_manager must stay enabled: with it disabled the meson build of
#    the Qt module fails to link (vlm.cpp is compiled out but its moc isn't).
#  - lua is disabled (no lua dev package needed).
MESON_OPTS=(
    --buildtype=debugoptimized
    --auto-features=disabled
    -Dqt=enabled -Dmedialibrary=enabled
    -Dxcb=enabled -Dx11=enabled
    -Davcodec=enabled -Davformat=enabled -Dswscale=enabled
    -Dfreetype=enabled -Dfontconfig=enabled
    -Dtaglib=enabled -Dpng=enabled -Djpeg=enabled
    -Dpulse=enabled -Dalsa=enabled
    -Dlua=disabled -Dtests=disabled -Dvcd_module=false
    -Dstream_outputs=true -Dvideolan_manager=true -Daddon_manager=false
    -Drun_as_root=true -Dqt_qml_debug=false
)

APT_PKGS=(
    build-essential pkg-config ninja-build python3-pip ccache git curl
    flex bison gettext
    libsqlite3-dev libtag1-dev libpng-dev libjpeg-dev
    libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libswresample-dev
    libx11-dev libx11-xcb-dev libxcb1-dev libxcb-shm0-dev libxcb-composite0-dev
    libxcb-xkb-dev libxcb-randr0-dev libxcb-damage0-dev libxcb-xfixes0-dev
    libxcb-cursor-dev libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-image0-dev
    libxcb-render-util0-dev libxcb-util-dev libxcb-xinerama0-dev libxcb-xinput-dev
    libxcb-sync-dev libxcb-glx0-dev libxkbcommon-dev libxkbcommon-x11-dev
    libgl-dev libegl-dev libgles-dev libdrm-dev libvulkan-dev
    libfontconfig-dev libfreetype-dev libpulse-dev libasound2-dev
    libdbus-1-dev libglib2.0-dev
    libgl1-mesa-dri mesa-utils libxrender1 libxi6 libsm6 libice6
    xvfb xauth x11-utils x11-apps xdotool imagemagick ffmpeg
)

step() { echo; echo "=== $* ==="; }

install_apt() {
    local missing=()
    for p in "${APT_PKGS[@]}"; do
        dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "ok installed" || missing+=("$p")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        step "apt: installing ${#missing[@]} packages"
        apt-get update -q
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
    fi
}

install_pip() {
    local need=0
    command -v aqt >/dev/null || need=1
    if ! command -v meson >/dev/null || ! python3 -c "import sys,subprocess; v=subprocess.check_output(['meson','--version']).decode().strip().split('.'); sys.exit(0 if (int(v[0]),int(v[1]))>=(1,10) else 1)"; then
        need=1
    fi
    if [ $need = 1 ]; then
        step "pip: aqtinstall + meson>=1.10 (VLC master needs meson >= 1.10)"
        pip install --break-system-packages -q aqtinstall 'meson>=1.10'
    fi
}

install_qt() {
    if [ -x "$VLC_QT_DIR/bin/qmllint" ] && [ -d "$VLC_QT_DIR/lib/cmake/Qt6ShaderTools" ]; then
        return
    fi
    step "Qt $VLC_QT_VERSION via aqtinstall -> /opt/qt"
    mkdir -p /opt/qt
    aqt install-qt linux desktop "$VLC_QT_VERSION" linux_gcc_64 -O /opt/qt \
        -m qtshadertools qt5compat qtimageformats
}

install_medialibrary() {
    if PKG_CONFIG_PATH="$VLC_DEPS/lib/pkgconfig" pkg-config --atleast-version=0.13.0 medialibrary 2>/dev/null; then
        return
    fi
    step "medialibrary $ML_VERSION -> $VLC_DEPS"
    local src=/opt/src
    mkdir -p "$src/ml-dl"
    local tb="$src/ml-dl/medialibrary-$ML_VERSION.tar.bz2"
    [ -f "$tb" ] || curl -fsSL -o "$tb" \
        "https://code.videolan.org/videolan/medialibrary/-/archive/$ML_VERSION/medialibrary-$ML_VERSION.tar.bz2"
    # checksum from upstream contribs
    local want
    want="$(awk '{print $1}' "$VLC_SRC/contrib/src/medialibrary/SHA512SUMS")"
    echo "$want  $tb" | sha512sum -c - >/dev/null || die "medialibrary tarball checksum mismatch"
    rm -rf "$src/ml-dl/medialibrary-$ML_VERSION" "$src/ml-build"
    tar -C "$src/ml-dl" -xjf "$tb"
    meson setup "$src/ml-build" "$src/ml-dl/medialibrary-$ML_VERSION" --prefix="$VLC_DEPS" \
        --libdir=lib --buildtype=release -Dlibvlc=disabled -Dtests=disabled
    ninja -C "$src/ml-build" install
}

make_media() {
    [ -f "$VLC_MEDIA/test-720p.mp4" ] && [ -d "$VLC_MEDIA/Music" ] && return
    step "sample media -> $VLC_MEDIA"
    local M="$VLC_MEDIA" ff="ffmpeg -loglevel error -y"
    mkdir -p "$M/Videos" "$M/Music/Demo Artist/Demo Album" "$M/Music/Other Artist/Second Album"
    $ff -f lavfi -i testsrc2=size=1280x720:rate=25:duration=60 -f lavfi -i sine=frequency=440:duration=60 \
        -c:v libx264 -pix_fmt yuv420p -preset veryfast -c:a aac -metadata title="Test Pattern" "$M/test-720p.mp4"
    cp "$M/test-720p.mp4" "$M/Videos/Test Pattern.mp4"
    $ff -f lavfi -i "mandelbrot=size=1280x720:rate=25" -t 20 -c:v libx264 -pix_fmt yuv420p -preset veryfast \
        -metadata title="Mandelbrot Zoom" "$M/Videos/Mandelbrot Zoom.mp4"
    $ff -f lavfi -i "life=size=640x360:mold=10:rate=25:ratio=0.1:death_color=#C83232:life_color=#00ff00,scale=1280:720:flags=neighbor" \
        -t 20 -c:v libx264 -pix_fmt yuv420p -preset veryfast -metadata title="Game of Life" "$M/Videos/Game of Life.mp4"
    $ff -f lavfi -i "cellauto=s=1280x720:rule=110,format=yuv420p" -t 15 -c:v libx264 -preset veryfast \
        "$M/Videos/Cellular Automaton.mp4"
    $ff -f lavfi -i "gradients=s=600x600:c0=#ff7b00:c1=#7a00ff:x0=0:y0=0:x1=600:y1=600" -frames:v 1 "$M/cover1.png"
    $ff -f lavfi -i "gradients=s=600x600:c0=#00c2ff:c1=#003a7a:x0=0:y0=600:x1=600:y1=0" -frames:v 1 "$M/cover2.png"
    local i=1 f
    for f in 220 330 440 550 660; do
        $ff -f lavfi -i "sine=frequency=$f:duration=30" -i "$M/cover1.png" -map 0 -map 1 -c:a libmp3lame -b:a 128k \
            -c:v png -disposition:v attached_pic -id3v2_version 3 -metadata title="Track $i ($f Hz)" \
            -metadata artist="Demo Artist" -metadata album="Demo Album" -metadata track=$i \
            -metadata genre="Electronic" -metadata date=2024 "$M/Music/Demo Artist/Demo Album/0$i - Track $i.mp3"
        i=$((i+1))
    done
    i=1
    for f in 261 293 329 349; do
        $ff -f lavfi -i "sine=frequency=$f:duration=25" -i "$M/cover2.png" -map 0 -map 1 -c:a libmp3lame -b:a 128k \
            -c:v png -disposition:v attached_pic -id3v2_version 3 -metadata title="Note $i" \
            -metadata artist="Other Artist" -metadata album="Second Album" -metadata track=$i \
            -metadata genre="Ambient" -metadata date=2023 "$M/Music/Other Artist/Second Album/0$i - Note $i.mp3"
        i=$((i+1))
    done
}

configure_vlc() {
    if [ $reconfigure = 1 ] && [ -d "$VLC_BUILD" ]; then
        step "wiping $VLC_BUILD"
        rm -rf "$VLC_BUILD"
    fi
    if [ -f "$VLC_BUILD/build.ninja" ]; then
        local cfgsrc
        cfgsrc="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['directories']['source'])" "$VLC_BUILD/meson-info/meson-info.json")"
        [ "$(realpath "$cfgsrc")" = "$VLC_SRC" ] || die "$VLC_BUILD is configured for $cfgsrc, not $VLC_SRC (set VLC_BUILD or use --reconfigure)"
        echo "build dir $VLC_BUILD already configured for $VLC_SRC"
        return
    fi
    step "meson setup $VLC_BUILD (source $VLC_SRC)"
    meson setup "$VLC_BUILD" "$VLC_SRC" "${MESON_OPTS[@]}"
}

build_vlc() {
    step "building VLC (full build ~10 min on 4 cores)"
    local t=$(date +%s)
    ninja -C "$VLC_BUILD"
    echo "build took $(( $(date +%s) - t ))s"
}

case "$mode" in
    configure) configure_vlc; exit 0 ;;
    profile) "$_tools_dir/seed-profile.sh" "$VLC_PROFILE"; exit 0 ;;
esac

install_apt
install_pip
install_qt
install_medialibrary
make_media
[ "$mode" = deps ] && exit 0
configure_vlc
[ "$mode" = nobuild ] && exit 0
build_vlc
[ -d "$VLC_PROFILE/data/vlc/ml" ] || "$_tools_dir/seed-profile.sh" "$VLC_PROFILE"
step "done"
echo "VLC_SRC=$VLC_SRC"
echo "VLC_BUILD=$VLC_BUILD"
echo "try: $_tools_dir/screenshot.sh /tmp/home.png"
