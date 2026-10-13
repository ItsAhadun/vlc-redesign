#!/usr/bin/env bash
# Static checks of the Qt interface packaging that the Linux meson harness
# cannot catch, because the Windows installer is an autotools build against
# the static contrib Qt:
#
#  1. QML imports: every `import X` of modules/gui/qt/**/*.qml|js must be a
#     VLC.* module or listed in qml-imports-allowlist.txt. The static contrib
#     Qt only provides/links the QML modules that upstream VLC uses; importing
#     anything else (QtQuick.Shapes, QtQuick.Effects, Qt5Compat...) works on
#     Linux with a full Qt, but on Windows the importing file fails to load
#     ('module "X" is not installed') and with it every file using it: the
#     main window stays blank.
#  2. QML module lists: per module, the QML files and singletons listed in
#     modules/gui/qt/meson.build and modules/gui/qt/Makefile.am must match
#     (the harness builds with meson, the Windows installer with autotools).
#  3. Resources: every file referenced by assets.qrc exists and the ones of
#     modules/gui/qt are in libqt_plugin_la_RES of Makefile.am (autotools rcc
#     dependencies).
#
# usage: qt-packaging-check.sh     (exit 1 on any failure)
# Run by qml-check.sh; no build needed.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

python3 -I - "$VLC_SRC" "$(dirname "${BASH_SOURCE[0]}")/qml-imports-allowlist.txt" <<'EOF'
import os, re, sys
src, allowf = sys.argv[1:3]
qt = os.path.join(src, "modules", "gui", "qt")
errors = []

# --- 1. QML imports ----------------------------------------------------------
allow = {l.split("#", 1)[0].strip() for l in open(allowf)} - {""}
imp_re = re.compile(r'^\s*import\s+([A-Za-z][A-Za-z0-9_.]*)', re.M)
for root, dirs, files in os.walk(qt):
    for f in files:
        if not f.endswith((".qml", ".js", ".mjs")):
            continue
        p = os.path.join(root, f)
        text = open(p, errors="replace").read()
        for m in imp_re.finditer(text):
            mod = m.group(1)
            if mod == "VLC" or mod.startswith("VLC.") or mod in allow:
                continue
            line = text.count("\n", 0, m.start()) + 1
            errors.append(f"{os.path.relpath(p, src)}:{line}: QML module '{mod}' is not in "
                          f"design/tools/qml-imports-allowlist.txt (not available in the "
                          f"Windows static Qt: the file would fail to load)")

# --- 2. meson.build vs Makefile.am QML module lists ---------------------------
meson = open(os.path.join(qt, "meson.build")).read()
am = open(os.path.join(qt, "Makefile.am")).read()

def files_block(text, start):
    # contents of the files( ... ) call starting at/after start
    i = text.index("files(", start) + len("files(")
    depth, j = 1, i
    while depth:
        depth += {"(": 1, ")": -1}.get(text[j], 0)
        j += 1
    return set(re.findall(r"'([^']+)'", text[i:j - 1]))

meson_mods = {}
for m in re.finditer(r"qml_modules \+= \{(.*?)\n\s*\}\s*\n", meson, re.S):
    block = m.group(1)
    t = re.search(r"'target'\s*:\s*'([^']+)'", block).group(1)
    entry = {"QML": set(), "Singleton_QML": set()}
    for key, var in (("sources", "QML"), ("singletons", "Singleton_QML")):
        k = re.search(rf"'{key}'\s*:", block)
        if k:
            entry[var] = files_block(block, k.end())
    meson_mods[t] = entry

am_text = am.replace("\\\n", " ")
def am_var(name):
    m = re.search(rf"^{re.escape(name)}\s*=(.*)$", am_text, re.M)
    return set(m.group(1).split()) if m else None

for t, entry in sorted(meson_mods.items()):
    for var in ("QML", "Singleton_QML"):
        a = am_var(f"libqml_module_{t}_a_{var}")
        if a is None:
            if entry[var]:
                errors.append(f"Makefile.am: libqml_module_{t}_a_{var} missing (meson lists {len(entry[var])} files)")
            continue
        for f in sorted(entry[var] - a):
            errors.append(f"Makefile.am: {f} listed in meson.build ({t} {var}) but not in libqml_module_{t}_a_{var}")
        for f in sorted(a - entry[var]):
            errors.append(f"meson.build: {f} listed in Makefile.am libqml_module_{t}_a_{var} but not in meson.build")
for f in sorted({f for e in meson_mods.values() for v in e.values() for f in v}):
    if not os.path.exists(os.path.join(qt, f)):
        errors.append(f"meson.build/Makefile.am: {f} does not exist")

# --- 3. resources -------------------------------------------------------------
# rcc only reads assets.qrc; libqt_plugin_la_RES is the autotools dependency
# list of assets.cpp (it has extra upstream entries, only check one direction)
qrc = set(re.findall(r"<file[^>]*>([^<]+)</file>", open(os.path.join(qt, "assets.qrc")).read()))
res = am_var("libqt_plugin_la_RES") or set()
for f in sorted(qrc):
    if not os.path.exists(os.path.join(qt, f)):
        errors.append(f"assets.qrc: {f} does not exist")
    elif not f.startswith("../") and f not in res:
        errors.append(f"Makefile.am: {f} (assets.qrc) is not in libqt_plugin_la_RES")

for e in errors:
    print(f"PACKAGING {e}")
print(f"qt-packaging-check: {len(errors)} error(s)", file=sys.stderr)
sys.exit(1 if errors else 0)
EOF
