# Shared environment for the design/tools scripts. Source it, don't run it.
#
# Variables (all overridable from the environment):
#   VLC_SRC      VLC source tree (default: the checkout containing this script,
#                so running the scripts from a git worktree targets that worktree)
#   VLC_BUILD    meson build dir for VLC_SRC (default: /home/user/vlc-build for
#                the main checkout, /home/user/vlc-build-<worktree-name> otherwise)
#   VLC_QT_DIR   Qt 6 prefix (default: /opt/qt/6.8.3/gcc_64, installed by setup.sh)
#   VLC_DEPS     prefix with extra deps built from source (medialibrary)
#   VLC_MEDIA    sample media dir created by setup.sh (default: /opt/vlc-media)

_tools_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${VLC_SRC:=$(cd "$_tools_dir/../.." && pwd)}"
VLC_SRC="$(cd "$VLC_SRC" && pwd)"
if [ -z "${VLC_BUILD:-}" ]; then
    if [ "$VLC_SRC" = "/home/user/vlc-redesign" ]; then
        VLC_BUILD=/home/user/vlc-build
    else
        VLC_BUILD="/home/user/vlc-build-$(basename "$VLC_SRC")"
    fi
fi
: "${VLC_QT_VERSION:=6.8.3}"
: "${VLC_QT_DIR:=/opt/qt/$VLC_QT_VERSION/gcc_64}"
: "${VLC_DEPS:=/opt/vlc-deps}"
: "${VLC_MEDIA:=/opt/vlc-media}"

export VLC_SRC VLC_BUILD VLC_QT_DIR VLC_DEPS VLC_MEDIA
export PATH="$VLC_QT_DIR/bin:$PATH"
export PKG_CONFIG_PATH="$VLC_QT_DIR/lib/pkgconfig:$VLC_DEPS/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export LD_LIBRARY_PATH="$VLC_QT_DIR/lib:$VLC_DEPS/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LC_ALL="${LC_ALL:-C.UTF-8}"

die() { echo "error: $*" >&2; exit 1; }

require_build() {
    [ -f "$VLC_BUILD/build.ninja" ] || die "no configured build in $VLC_BUILD (run design/tools/setup.sh --configure-only, or set VLC_BUILD)"
}
