# Local Qt/QML UI verification harness

Fast local loop for the Qt/QML interface (`modules/gui/qt`) on Linux, so UI
changes can be checked without waiting for the 1h+ Windows installer CI:

| step | command | time |
|---|---|---|
| static QML check | `design/tools/qml-check.sh --changed` | ~1 s (all 248 files: ~7 s) |
| rebuild Qt plugin after QML edits | `design/tools/build-qt.sh` | ~10 s |
| screenshot of the real UI | `design/tools/screenshot.sh out.png` | ~7-10 s |

Everything runs headless (Xvfb). The build is a native Linux build of VLC
master with the same Qt version as the Windows contribs (6.8.3), so the UI
is the same as on Windows, except for platform bits (no Windows CSD/acrylic
blur effect, the X11 window is undecorated).

## Setup (once per machine / container)

```sh
design/tools/setup.sh        # ~15 min from scratch, idempotent
```

It installs, in order (each step is skipped if already done):

* apt packages: compilers, X/xcb/GL dev libs, ffmpeg dev libs, taglib,
  sqlite, Xvfb, xdotool, imagemagick, ffmpeg (CLI)
* pip: `aqtinstall`, `meson>=1.10` (VLC master needs meson 1.10; Ubuntu 24.04
  has 1.3)
* **Qt 6.8.3** (gcc_64 + qtshadertools, qt5compat, qtimageformats; qtsvg and
  qtdeclarative are part of the base) with aqtinstall into
  `/opt/qt/6.8.3/gcc_64`. VLC requires Qt >= 6.2, Ubuntu 24.04 ships 6.4.2,
  but the Windows build uses 6.8.3 (`contrib/src/main.mak`), and the code has
  many `QT_VERSION_CHECK(6, 5..9)` paths, so we match Windows.
* **medialibrary 0.13.2** (VLC requires >= 0.13, Ubuntu has 0.12.3) built
  from the upstream tarball (checksum from `contrib/src/medialibrary/SHA512SUMS`)
  into `/opt/vlc-deps`, with `-Dlibvlc=disabled` exactly like contribs.
* sample media in `/opt/vlc-media` (4 videos in `Videos/`, 2 tagged mp3
  albums with cover art in `Music/`, `test-720p.mp4` 60 s test pattern).
* meson build dir (see below) + full build (~6-7 min on 4 cores).
* a profile template `/opt/vlc-profile` whose media library indexed
  `/opt/vlc-media` (`seed-profile.sh`, runs the first-run wizard via xdotool).

Other options: `--no-build`, `--deps-only`, `--configure-only`,
`--reconfigure` (wipe + configure), `--profile` (re-seed profile only).

### Build configuration

`meson setup` with `--buildtype=debugoptimized --auto-features=disabled` and
only: `qt medialibrary xcb x11 avcodec avformat swscale freetype fontconfig
taglib png jpeg pulse alsa`, `lua=disabled`, `stream_outputs=true`,
`videolan_manager=true` (must stay on: with VLM disabled the meson build of the
Qt module fails to link `moc_vlm.cpp`, an upstream meson bug). See
`MESON_OPTS` in `setup.sh`. The media library is enabled and working, so all
library views (Home, Video, Music artists/albums/tracks, Browse) have content.

### Source / build dirs and git worktrees

All scripts use (see `_common.sh`):

* `VLC_SRC` - source tree. Default: the checkout containing the script, so
  `path/to/worktree/design/tools/build-qt.sh` targets that worktree.
* `VLC_BUILD` - build dir. Default: `/home/user/vlc-build` for
  `/home/user/vlc-redesign`, else `/home/user/vlc-build-<worktree dir name>`.
* `VLC_QT_DIR`, `VLC_DEPS`, `VLC_MEDIA`, `VLC_PROFILE` - see above.

A new worktree gets its own build dir: the first `build-qt.sh` there
configures it and does a full build (~6-7 min; ccache is used for new build
dirs), later runs are incremental. `qml-check.sh` doesn't need a build of the
worktree: it falls back to the main build dir's generated QML module lists.

## qml-check.sh - static QML check (qmllint)

```sh
design/tools/qml-check.sh                       # all QML of modules/gui/qt
design/tools/qml-check.sh --changed             # files changed vs HEAD + untracked
design/tools/qml-check.sh modules/gui/qt/player/qml/ControlBar.qml modules/gui/qt/style/
design/tools/qml-check.sh --show-known ...      # also show baseline (upstream) findings
design/tools/qml-check.sh --all-warnings ...    # raw qmllint output, unfiltered
```

Exit status 1 if there are errors. Output: `file:line:col: ERROR|warning: msg [category]`
plus `hint:` lines (e.g. `Did you mean "Rectangle"?`).

* qmllint 6.8.3 runs on a symlinked import tree mirroring the
  `VLC.*` QML modules (`$VLC_BUILD/qmllint-tree`), so `import VLC.Widgets` etc.
  resolve to the files in your source tree.
* Types registered from C++ (MainCtx, Navigation, ColorContext, models...) are
  invisible to qmllint; findings about names that exist as C++ classes /
  `qmlRegister*` names / `Q_PROPERTY`s in `modules/gui/qt` are dropped.
* Findings that already exist upstream are listed in `qmllint-baseline.txt`
  (file + category + message, no line numbers) and hidden. Regenerate it only
  from an unmodified upstream tree: `qml-check.sh --update-baseline`.
* ERROR (exit 1): syntax errors, unknown components (`Rectangl was not
  found`), duplicate names, alias/inheritance cycles, read-only property
  writes, bad signal handler params, ...  warning (exit 0): missing
  properties on QML types, PropertyChanges style, required properties, ...
* A QML file that is not listed in `modules/gui/qt/meson.build` is reported
  as `NOT-IN-MESON` (it would not be packaged in the plugin).
* qmllint can't catch everything (e.g. duplicate property bindings, errors in
  JS on C++ objects): `screenshot.sh` prints the QML runtime warnings too.

## build-qt.sh - incremental build

```sh
design/tools/build-qt.sh          # builds modules/libqt_plugin.so (+ qt_x11 helper)
design/tools/build-qt.sh --all    # whole build dir (vlc binary + all plugins)
```

QML/JS/SVG/qrc edits: rcc + relink, ~10 s. The QML is compiled into the
plugin as Qt resources, so **always rebuild before taking screenshots**. A
new QML file must be added to `modules/gui/qt/meson.build` (ninja re-runs
meson by itself).

## screenshot.sh - headless screenshots of the real UI

```sh
design/tools/screenshot.sh out.png                         # Home (library) view
design/tools/screenshot.sh --theme dark out.png
design/tools/screenshot.sh out.png /opt/vlc-media/test-720p.mp4   # player view (paused at 0)
design/tools/screenshot.sh --at 10 out.png "/opt/vlc-media/Music/Demo Artist/Demo Album/01 - Track 1.mp3"
design/tools/screenshot.sh --size 1280x720 --scale 1.25 out.png
design/tools/screenshot.sh --do "click 60 127" --do "sleep 2" music.png   # Music view
design/tools/screenshot.sh out.png -- --qt-minimal-view    # extra VLC options after --
```

* Starts its own Xvfb (free display picked automatically), so several
  screenshots can run in parallel. The screen and the main window are
  `--size WxH` (default **1920x1080**); the window is moved/resized to cover
  the whole screen (there is no window manager).
* Each run uses a throw-away copy of the profile template (`--profile none`
  for an empty profile with an empty library; `--keep-profile DIR` to keep the
  run's profile). QML disk cache is disabled so you always see fresh QML.
* **Theme**: `--theme light|dark|system` sets `MainWindow/color-scheme-index`
  (1 = Day, 2 = Night, 0 = System) in `vlc/vlc-qt-interface.conf` of the run's
  profile. **Window size**: `--size`. **Interface scale**: `--scale` (VLC
  `--qt-interface-scale`).
* With a media file VLC starts with `--start-paused` (stable frame, controls
  visible); `--playing` to let it play, `--at SECONDS` to seek. Audio goes to
  the `adummy` output.
* `--do ACTION` (repeatable) drives the UI before the capture:
  `click X Y`, `dclick X Y`, `move X Y` (hover), `key ctrl+l`, `type text`,
  `sleep S`, `shot extra.png` (intermediate screenshot).
* The VLC log is written next to the PNG (`out.log`, or `--log FILE`) and the
  QML runtime warnings/errors (`qrc:/qt/qml/VLC/...qml:LINE: ...`) are printed
  - treat new ones as failures.

Sidebar click targets at 1920x1080, scale 1 (default modern layout, as in
the seeded profile): Home `60 57`, Video `60 92`, Music `60 127`, Browse
`60 162`, Discover `60 197`, Preferences `60 1050`. After clicking Music the
sub-items appear: Artists `60 162`, Albums `60 197`, Tracks `60 232`,
Genres `60 267`, Playlists `60 302` (Browse/Discover move down to 337/372).
After Video: All `60 127`, Playlists `60 162` (Music/Browse/Discover move to
197/232/267). Play queue toggle: top right (`1734 20`). Positions shift with
`--scale` and `--size`; take a screenshot first and read coordinates off it.

### Known limitations

* **Video is not embedded in screenshots.** Under Xvfb VLC's X11 compositor
  (which composites the video under the QML UI) shows only the raw video, the
  UI is not visible (window not redirected/composited correctly in Xvfb). So
  screenshot.sh uses `--qt-compositor=dummy` by default: the full player UI is
  rendered, with the "video plays in an external window" placeholder card in
  place of the video (the separate video window is hidden before capture).
  `--compositor x11` restores the embedded mode if you want to try.
* The software GL renderer (Mesa llvmpipe) is used; Windows-only effects
  (acrylic/DirectComposition blur, Windows CSD) are not available, VLC falls
  back to its simulated effects.
* VLC sometimes segfaults on SIGTERM at shutdown in this headless setup; it
  is harmless (the screenshot is taken before) and silenced by the scripts.
* The "Screen capture" error toast in Browse comes from the screen:// device
  entry (no screen capture module in this minimal build).

## Files

* `setup.sh` - environment bootstrap (see above)
* `seed-profile.sh` - (re)create `/opt/vlc-profile`
* `qml-check.sh` + `qmllint-baseline.txt` - static QML check
* `build-qt.sh` - incremental build
* `screenshot.sh` - headless screenshots
* `_common.sh` - shared env (paths, Qt/pkg-config env)
