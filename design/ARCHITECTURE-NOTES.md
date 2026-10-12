# Architecture notes (redesign)

## 1. Design tokens (foundation layer)

All screen work should read colors, type and metrics from these tokens instead
of hard-coding values. Source of truth: `design/SPEC.md` section 1.

### Colors: `SystemPalette` (`modules/gui/qt/style/systempalette.*`)

Two layers, both resolved for the current theme (Day/Night/System) and accent:

* **Semantic color sets** (unchanged API): `ColorContext { colorSet: ColorContext.Window }`
  then `theme.bg.primary`, `theme.fg.secondary`, `theme.accent`, ...
  The Day and Night palettes are now built from the design tokens in
  `SystemPalette::makeTokenPalette()`. Main mapping (dark / light):

  | set | role | token |
  |---|---|---|
  | View | bg.primary / bg.secondary | BG/B1 page / BG/B2 wells |
  | View | fg.primary / fg.secondary | FG/2 / FG/A2 (light: FG/A2 / FG/A3) |
  | View | separator / border | Divider/Dim / Divider/Bright |
  | Window (title bar, control bar, nav pane, miniplayer, dialogs) | bg.primary | BG/A3 (light: BG/A4, see SPEC light caveat) |
  | Item | bg.primary hovered, bg.highlight | BG/A1 (light: BG/A2, BG/A3) |
  | ToolButton / TabButton | fg.primary normal / hovered | FG/A2 / FG/1 (light: FG/A3 / FG/A2); ToolButton hover bg = hover overlay |
  | ButtonAccent | bg normal / hovered / pressed, fg | Accent/Main / Accent/Bright / Accent/DIm, fgOnAccent |
  | Slider | bg.primary, fg.primary | BG/B2 track, Accent/Main |
  | Switch | off track / knob, on track / knob | BG/B2 / FG/A4, BG/Accent Bright / Accent/DIm |
  | all | `accent`, `fg.link` | Accent/Main |

* **Raw tokens** (new, Figma names in camelCase) as properties of the palette:
  `theme.palette.<token>` from any `ColorContext`, or `VLCStyle.palette.<token>`
  (`VLCStyle.darkPalette.<token>` for the always-dark player):

  `fg1 fg2 fgA1 fgA2 fgA3 fgA4 fgB1`,
  `bgA1 bgA2 bgA3 bgA4 bgA5 bgB1 bgB2 bgA3Transparent bgB1Transparent bgB2Transparent`,
  `dividerBright dividerDim`,
  `accentMain accentBright accentDim accentLogo bgAccentBright bgAccentDark fgOnAccent`,
  `hoverOverlay volumeTrack volumeGauge volumeGaugeLow volumeGaugeMid volumeGaugeHigh volumeGaugePeak`.

  `fgOnAccent` is FG/B1 `#161616` or FG/1 `#eaeaea`, whichever contrasts more
  with the current accent (dark accents such as red/blue get light glyphs).

* The "System" theme follows the OS dark/light setting but always uses the
  VLC token palette (on Windows the OS palette is still used in high contrast
  mode, as before).

### Accent: `MainCtx`

* `MainCtx.accentPresets` - the 9 swatches (SPEC 1.2), index 0 = orange default.
* `MainCtx.accentIndex` (read/write, `-1` for a custom or system color).
* `MainCtx.accentColor` - the selected base swatch color (read only).
* `MainCtx.setAccentColor(string)` - `"default"`, `"system"` or `"#rrggbb"`.
* Persisted in the vlcrc option `qt-accent-color` (string, default `default`).
  Every palette and all `ColorContext`s update live on change.
* Tints are derived in `SystemPalette::makeDesignTokens()` (SPEC 1.3); light
  theme: Main = A x 1.10 (exactly reproduces `#e8851a`), Dim = Main x 0.65,
  Logo = Main x 0.84, Bright = HSV rule, BG/Accent Bright/Dark = mix with
  `#cfcfcf` / `#bdbdbd` at 30 %.

### Typography and metrics: `VLCStyle`

* Inter (Regular/Medium/SemiBold/Bold, `modules/gui/qt/fonts/`, OFL) is loaded
  in `qt.cpp` (`loadApplicationFonts`) and set as the application font, so every
  `Text` uses it by default. `VLCStyle.fontFamily`.
* `VLCStyle.fontSize_caption|body|title|headline|display` (12/14/16/24/32),
  `VLCStyle.lineHeight_caption|body|bodyRelaxed|title|titleRelaxed|headline|headlineRelaxed|display`
  (use with `lineHeightMode: Text.FixedHeight`),
  `VLCStyle.fontWeight_regular|medium|semiBold|bold|heading`.
* Spacing `VLCStyle.space_2 ... space_28`, radii `VLCStyle.radius_xxsmall (2) ... radius_xlarge (12)`.
* Layout and component sizes: `titleBar_height`, `controlBar_height` (54),
  `navPane_width` (200), `navRail_width` (50), `playerSidePanel_width` (427),
  `iconWrapper_width/height`, `playButton_width/height`, `volumeWidget_width`,
  `toggle_width/height`, `videoCard_width/height`, `musicCard_size`,
  `card_spacing`, `miniPlayer_*`, `settingsWindow_*`, `popupShadow_*`, ...
  The pre-existing properties (`controlLayoutHeight` 64, `expandNavigationPaneWidth`
  160, `fontSize_*`, ...) are unchanged; screens switch to the new ones when
  they are restyled.

## 2. Icons: swapping in the 96 new Figma icons

### How VLC renders icons today

1. **Icon font (main mechanism).** `modules/gui/qt/pixmaps/VLCIcons.json` lists
   96 glyphs (`key` -> `./icons/<file>.svg`). `pixmaps/makeIconFont.py`
   (FontForge Python) turns them into `pixmaps/VLCIcons.ttf` and regenerates
   `style/vlcicons.hpp` / `style/vlcicons.cpp` (a QML singleton `VLCIcons` with
   one `QChar` constant per key, private-use code points from U+E000 in JSON
   order, plus `VLCIcons.fontFamily`). QML draws them as text:
   `IconLabel { text: VLCIcons.play }`, `IconToolButton`, `IconButton`,
   `CSDWindowButton` set `font.family: VLCIcons.fontFamily`; the color is just
   the text color, so ColorContext states (hover, accent, disabled) apply for
   free. C++ also uses the keys (`navigationmodel.cpp`: `VLCIcons::home`, ...).
   The TTF and the generated hpp/cpp are committed, so builds (and the Windows
   CI) do not need FontForge.
2. **Colorized SVG.** `image://svgcolor/...` (`util/color_svg_image_provider.*`,
   QML helper `SVGColorImage.colorize(url).color1(c).accent(c).uri()`) rewrites
   placeholder colors (`_res_C1`, `_res_C2`, `_res_ACCENT`, `_res_BG`) inside an
   SVG at load time. Used for multi-color art (placeholders, service icons) and
   by `ColorizedSvgIcon` for QWidget menus (`:/menu/*.svg`, `:/icons/ic_fluent_*.svg`).

### Recommended path: regenerate the icon font

The new set is monochrome 24x24 glyphs recolored at runtime (INDEX.md: inactive
FG/A2, active = accent), which is exactly what the icon font does, and it keeps
every existing call site (`VLCIcons.<key>`) working.

1. Export the SVGs (`design/icons/manifest.json`, recipe in SPEC section 6) into
   `modules/gui/qt/pixmaps/icons/` (new names, e.g. `rd_<name>.svg`, so the old
   ones stay until all screens move).
2. Pre-process each SVG for FontForge (the script's known issues): outline
   strokes and remove overlaps (e.g. `inkscape --actions="select-all;object-stroke-to-path;path-union;export-plain-svg"`
   or `picosvg`), and make the `viewBox` equal to the size (`0 0 24 24`).
   Figma exports often contain strokes and `fill="#8F8F8F"`; the color is
   irrelevant for a glyph, but strokes are dropped by `importOutlines`.
3. Point the existing keys at the new files in `VLCIcons.json` (`"play"` ->
   `./icons/rd_play.svg`), and append new keys for icons that have no
   equivalent (`backward_15_sec`, `pip`, `hdr`, ...). Use the Figma `name`
   (+ direction/value) in snake_case as the key; `-active` state variants are
   usually the same glyph in the accent color, so they do not need a key unless
   the shape differs (then add `<key>_active`).
4. Run `cd modules/gui/qt/pixmaps && python3 makeIconFont.py VLCIcons.json`
   (needs `python3-fontforge`, available on Linux only; run it locally and
   commit the outputs `VLCIcons.ttf`, `../style/vlcicons.hpp`, `../style/vlcicons.cpp`).
   No build-system change is needed: the TTF is already in `assets.qrc` and in
   `Makefile.am` (`libqt_plugin_la_RES`), and the hpp/cpp are already listed in
   both `meson.build` and `Makefile.am`.
5. Check the metrics: the glyphs are drawn at `font.pixelSize` =
   `VLCStyle.icon_normal` (24). If the Figma icons have padding inside the
   24 box they will look smaller than the old ones; adjust in step 2, not in QML.

### Two-tone icons

A font glyph has one color. For the few `-twotone` icons either
(a) split them into two glyphs (`<key>` and `<key>_accent`) and stack two
`IconLabel`s with different colors, or (b) use the svgcolor provider with
`_res_C1` / `_res_ACCENT` placeholders in the SVG fills and an `Image` (sized in
`VLCStyle.icon_normal`, `sourceSize` set for HiDPI). (a) keeps hover/disabled
colors automatic; prefer it unless the shapes overlap.

### Why not SVG `Image` everywhere

Switching all call sites to `Image { source: "qrc:/icons/x.svg" }` would require
editing ~30 QML components plus C++ (`navigationmodel.cpp`), re-rasterizing for
each color/state change (the svgcolor provider is async and caches per color),
and handling `sourceSize` for every scale factor. The font path is a data-only
change.
