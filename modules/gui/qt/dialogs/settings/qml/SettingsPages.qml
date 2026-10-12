/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Dialogs

// Content of the settings window: every page, section and row of the Figma
// "Settings - *" frames (design/SPEC.md 2.3), each row bound to a real VLC
// option. Row fields are documented in SettingsRow.qml. Sections with
// `advanced: true` are revealed by the "Advanced Options" bar, sections with
// `developer: true` additionally need "Developer mode" (qt-developer-mode).
QtObject {
    id: root

    // -- helpers -----------------------------------------------------------

    readonly property string unavailableText: qsTr("This setting is not available yet in this version of VLC.")

    function value(key) {
        return SettingsBackend.value(key)
    }

    function set(key, v) {
        SettingsBackend.setValue(key, v)
    }

    // toggle bound to the presence of a module in a ':' separated list option
    function listToggle(label, key, item, extra) {
        return Object.assign({
            label: label, type: "toggle", info: true,
            help: SettingsBackend.moduleExists(item) ? "" : unavailableText,
            unavailable: SettingsBackend.moduleExists(item) ? undefined : unavailableText,
            get: () => SettingsBackend.listHas(key, item),
            set: (on) => SettingsBackend.setListItem(key, item, on)
        }, extra ?? {})
    }

    function secondsTicks(from, to) {
        return [ { value: from, label: qsTr("%1 s").arg(from) },
                 { value: (from + to) / 2, label: qsTr("%1 s").arg((from + to) / 2) },
                 { value: to, label: qsTr("%1 s").arg(to) } ]
    }

    readonly property var percentTicks: [
        { value: 0, label: "0%" }, { value: 50, label: "50%" }, { value: 100, label: "100%" }
    ]

    // languages for the audio/subtitle/menu language options (ISO 639)
    readonly property var languageCodes: [
        ["en", "English"], ["fr", "Français"], ["de", "Deutsch"], ["es", "Español"],
        ["it", "Italiano"], ["pt", "Português"], ["nl", "Nederlands"], ["sv", "Svenska"],
        ["da", "Dansk"], ["no", "Norsk"], ["fi", "Suomi"], ["pl", "Polski"],
        ["cs", "Čeština"], ["hu", "Magyar"], ["ro", "Română"], ["el", "Ελληνικά"],
        ["tr", "Türkçe"], ["ru", "Русский"], ["uk", "Українська"], ["ar", "العربية"],
        ["he", "עברית"], ["hi", "हिन्दी"], ["ja", "日本語"], ["ko", "한국어"],
        ["zh", "中文"], ["th", "ไทย"], ["vi", "Tiếng Việt"], ["id", "Bahasa Indonesia"]
    ]

    function languageChoices(key) {
        const list = [ { value: "", text: qsTr("System language") } ]
        for (const l of languageCodes)
            list.push({ value: l[0], text: l[1] })
        const current = SettingsBackend.value(key)
        if (current && !list.some((c) => c.value === current))
            list.push({ value: current, text: current })
        return list
    }

    function withCurrent(list, key) {
        const current = SettingsBackend.value(key)
        if (current !== undefined && current !== "" && !list.some((c) => c.value === current))
            return list.concat([ { value: current, text: String(current) } ])
        return list
    }

    // picture adjustments: keep the "adjust" video filter enabled only while
    // one of them differs from its default
    readonly property var pictureKeys: ["hue", "brightness", "contrast", "saturation", "gamma"]

    function pictureRow(label, key, from, to) {
        return {
            label: label, type: "slider", key: key, from: from, to: to,
            format: (v) => v.toFixed(2),
            enabledWhen: () => SettingsBackend.moduleExists("adjust"),
            unavailable: SettingsBackend.moduleExists("adjust") ? undefined : unavailableText,
            set: (v) => {
                SettingsBackend.setValue(key, v)
                root.syncAdjustFilter()
            }
        }
    }

    function syncAdjustFilter() {
        const modified = pictureKeys.some((k) => Math.abs(Number(SettingsBackend.value(k)) - Number(SettingsBackend.defaultValue(k))) > 1e-3)
        SettingsBackend.setListItem("video-filter", "adjust", modified)
    }

    // network caching presets: [file, disc, network, live] in ms
    readonly property var cachingKeys: ["file-caching", "disc-caching", "network-caching", "live-caching"]
    readonly property var cachingPresets: [
        { value: 0, text: qsTr("Low latency"), values: [300, 300, 300, 100] },
        { value: 1, text: qsTr("Normal"), values: [1000, 300, 1000, 300] },
        { value: 2, text: qsTr("High"), values: [3000, 2000, 5000, 1000] }
    ]

    // -- pages ---------------------------------------------------------------

    readonly property var groups: [
        { name: qsTr("App"), pages: ["general", "interface", "privacy", "controls"] },
        { name: qsTr("Media"), pages: ["playback", "video", "audio", "subtitles", "library"] },
        { name: qsTr("System"), pages: ["network", "performance", "recording", "extensions"] }
    ]

    function page(id) {
        return pages.find((p) => p.id === id)
    }

    readonly property var pages: [
        {
            id: "general", name: qsTr("General"), title: qsTr("Global Settings"), icon: "general",
            sections: [
                { title: qsTr("Appearance"), rows: [
                    { label: qsTr("Interface language"), type: "dropdown",
                      choices: () => SettingsBackend.languages(),
                      get: () => SettingsBackend.language(),
                      set: (v) => SettingsBackend.setLanguage(v),
                      help: qsTr("Restart VLC to use the new language."),
                      enabledWhen: () => SettingsBackend.languageEditable },
                    { label: qsTr("Theme"), type: "segmented",
                      choices: [ { value: 2, text: qsTr("Dark") }, { value: 1, text: qsTr("Light") },
                                 { value: 0, text: qsTr("System") } ],
                      get: () => SettingsBackend.colorSchemeIndex(),
                      set: (v) => SettingsBackend.setColorSchemeIndex(v) },
                    { label: qsTr("Accent color"), type: "accent", key: "qt-accent-color" }
                ] },
                { title: qsTr("Startup"), rows: [
                    { label: qsTr("Show confirmation and error dialogs"), info: true, key: "qt-error-dialogs" },
                    { label: qsTr("Check for updates automatically"), info: true, key: "qt-updates-notif" }
                ] },
                { title: qsTr("Diagnostics"), rows: [
                    { label: qsTr("Developer mode"), info: true, key: "qt-developer-mode" },
                    { label: qsTr("Save a log"), info: true, key: "file-logging" },
                    { label: qsTr("Log file"), info: true, type: "path", browse: "file", key: "logfile" },
                    // log-verbose -1 = follow the global verbosity ("verbose", 0 = errors)
                    { label: qsTr("Log details"), info: true, type: "dropdown", key: "log-verbose",
                      choices: [ { value: 0, text: qsTr("Errors only") }, { value: 1, text: qsTr("Warnings") },
                                 { value: 2, text: qsTr("Debug") } ],
                      get: () => {
                          const v = Number(SettingsBackend.value("log-verbose"))
                          return Math.min(2, Math.max(0, v >= 0 ? v : Number(SettingsBackend.value("verbose"))))
                      } }
                ] },
                { title: qsTr("Advanced"), advanced: true, rows: [
                    { label: qsTr("Show minor warnings"), info: true, key: "verbose",
                      get: () => Number(SettingsBackend.value("verbose")) >= 1,
                      set: (on) => SettingsBackend.setValue("verbose", on ? 1 : 0) },
                    { label: qsTr("Additional command line options"), info: true, type: "text",
                      unavailable: root.unavailableText },
                    { label: qsTr("Log format"), info: true, type: "dropdown", key: "logmode" },
                    { label: qsTr("Collect playback statistics"), info: true, key: "stats" },
                    { label: qsTr("Open configurations folder"), info: true, type: "button", buttonText: qsTr("Open"),
                      help: qsTr("Opens the folder where VLC keeps its settings files."),
                      action: () => SettingsBackend.openConfigFolder() },
                    { label: qsTr("Reset all settings"), info: true, type: "button", buttonText: qsTr("Reset"),
                      confirm: true,
                      help: qsTr("Restores every VLC setting to its default value. This can't be undone."),
                      action: () => SettingsBackend.resetAll() }
                ] },
                { title: qsTr("Developer Options"), advanced: true, developer: true, rows: [
                    { label: qsTr("Write to the system log"), info: true, key: "syslog" },
                    { label: qsTr("Include debug messages in the system log"), info: true, key: "syslog-debug" },
                    { label: qsTr("System log identity"), info: true, type: "text", key: "syslog-ident" },
                    { label: qsTr("System log facility"), info: true, type: "dropdown", key: "syslog-facility" }
                ] }
            ]
        },
        {
            id: "interface", name: qsTr("Interface"), title: qsTr("Interface Settings"), icon: "interface",
            sections: [
                { title: qsTr("Skin"), rows: [
                    { label: qsTr("Use a custom skin"), info: true, key: "intf",
                      help: qsTr("Uses the skinnable interface instead of this one. Restart VLC to apply."),
                      enabledWhen: () => SettingsBackend.moduleExists("skins2"),
                      get: () => SettingsBackend.value("intf") === "skins2",
                      set: (on) => SettingsBackend.setValue("intf", on ? "skins2" : "") },
                    { label: qsTr("Skin file"), info: true, type: "path", browse: "file", key: "skins2-last" }
                ] },
                { title: qsTr("Window"), rows: [
                    { label: qsTr("Play video inside main window"), info: true, key: "embedded-video" },
                    { label: qsTr("Resize window to fit video"), info: true, type: "dropdown", key: "qt-video-autoresize",
                      choices: [ { value: false, text: qsTr("Never") }, { value: true, text: qsTr("Always") } ] },
                    { label: qsTr("Remember window size and position"), key: "qt-remember-geometry" },
                    { label: qsTr("Keep window above other windows"), info: true, key: "video-on-top" },
                    { label: qsTr("Show window decorations"), info: true, key: "qt-titlebar" },
                    { label: qsTr("Show the file name in the title bar"), info: true, key: "qt-name-in-title" },
                    { label: qsTr("Open fullscreen on"), info: true, type: "dropdown", key: "qt-fullscreen-screennumber",
                      choices: () => SettingsBackend.screens() }
                ] },
                { title: qsTr("Playback Controls"), rows: [
                    { label: qsTr("Start in compact mode"), info: true, key: "qt-minimal-view" },
                    { label: qsTr("Auto-hide the controls"), info: true, type: "dropdown", key: "qt-autohide-controls" },
                    { label: qsTr("Hide after"), type: "slider", key: "mouse-hide-timeout", scale: 1000,
                      from: 0, to: 10, step: 0.5, ticks: root.secondsTicks(0, 10),
                      format: (v) => qsTr("%1 s").arg(v) },
                    { label: qsTr("Show controls in fullscreen"), info: true, key: "qt-fs-controller" }
                ] },
                { title: qsTr("Notifications and System Tray"), rows: [
                    { label: qsTr("Show a system tray icon"), info: true, key: "qt-system-tray" },
                    { label: qsTr("Start minimized to the tray"), info: true, key: "qt-start-minimized" },
                    { label: qsTr("Show a popup when the track changes"), info: true, type: "dropdown", key: "qt-notification" },
                    { label: qsTr("Popup duration"), type: "slider", key: "qt-notification-duration",
                      from: 0, to: 10, step: 1, ticks: root.secondsTicks(0, 10),
                      format: (v) => v === 0 ? qsTr("System default") : qsTr("%1 s").arg(v) }
                ] },
                { title: qsTr("Playlist"), rows: [
                    { label: qsTr("Show the playlist as a tree"), info: true, key: "playlist-tree" }
                ] },
                { title: qsTr("Advanced"), advanced: true, rows: [
                    { label: qsTr("Window opacity"), type: "slider", key: "qt-opacity", from: 0.1, to: 1, step: 0.05,
                      ticks: [ { value: 0.1, label: "10%" }, { value: 1, label: "100%" } ],
                      format: (v) => Math.round(v * 100) + "%" },
                    { label: qsTr("Pause video when window is minimized"), key: "qt-pause-minimized" },
                    { label: qsTr("Bring VLC to the front when playback starts"), info: true, type: "dropdown", key: "qt-auto-raise" },
                    { label: qsTr("Show cover art in the window when playing audio"), key: "qt-bgcone" },
                    { label: qsTr("Show the file browser inside the open dialog"), key: "qt-embedded-open" },
                    { label: qsTr("Allow the app icon to change"), key: "qt-icon-change" },
                    { label: qsTr("Fullscreen controls opacity"), type: "slider", key: "qt-fs-opacity", from: 0.1, to: 1, step: 0.05,
                      ticks: [ { value: 0.1, label: "10%" }, { value: 1, label: "100%" } ],
                      format: (v) => Math.round(v * 100) + "%" },
                    // qt-fs-sensitivity is the mouse distance (px) that shows the controls
                    { label: qsTr("Fullscreen controls sensitivity"), type: "slider", key: "qt-fs-sensitivity",
                      from: 0, to: 2, step: 1,
                      ticks: [ { value: 0, label: qsTr("Low") }, { value: 1, label: qsTr("Medium") },
                               { value: 2, label: qsTr("High") } ],
                      get: () => { const v = Number(SettingsBackend.value("qt-fs-sensitivity")); return v >= 10 ? 0 : v >= 3 ? 1 : 2 },
                      set: (i) => SettingsBackend.setValue("qt-fs-sensitivity", [20, 3, 1][Math.round(i)]) }
                ] }
            ]
        },
        {
            id: "privacy", name: qsTr("Privacy"), title: qsTr("Privacy Settings"), icon: "privacy",
            noAdvancedBar: true,
            sections: [
                { title: qsTr("History"), rows: [
                    { label: qsTr("Save recently played items"), info: true, key: "save-recentplay" },
                    { label: qsTr("Remember the playback position"), info: true, key: "restore-playback-pos",
                      get: () => Number(SettingsBackend.value("restore-playback-pos")) !== 0,
                      set: (on) => SettingsBackend.setValue("restore-playback-pos",
                                                             on ? Number(SettingsBackend.defaultValue("restore-playback-pos")) || 1 : 0) },
                    { label: qsTr("Never remember items matching"), info: true, type: "text", key: "qt-history-filter",
                      placeholder: qsTr("Regular expression") },
                    { label: qsTr("Clear history now"), info: true, type: "button", buttonText: qsTr("Clear"),
                      help: qsTr("Removes every item from the recently played list."),
                      enabledWhen: () => SettingsBackend.hasMediaLibrary,
                      action: () => SettingsBackend.clearHistory() }
                ] },
                { title: qsTr("Network"), rows: [
                    { label: qsTr("Fetch titles and cover art from the internet"), info: true, key: "metadata-network-access" },
                    root.listToggle(qsTr("Submit played tracks to last.fm"), "control", "audioscrobbler",
                                    { help: qsTr("Sends the titles of the tracks you play to your Last.fm profile.") }),
                    { label: qsTr("Last.fm username"), info: true, type: "text", key: "lastfm-username" },
                    { label: qsTr("Last.fm password"), info: true, type: "password", key: "lastfm-password" },
                    { label: qsTr("Last.fm submission URL"), info: true, type: "text", key: "scrobbler-url" }
                ] }
            ]
        },
        {
            id: "controls", name: qsTr("Controls"), title: qsTr("Mouse, Keyboard & Remote Controls"), icon: "controls",
            sections: [
                { title: qsTr("Keyboard Shortcuts"), rows: [
                    { label: qsTr("Defaults"), type: "button", wide: true, buttonText: qsTr("Edit Keyboard Shortcuts"),
                      action: () => SettingsBackend.openHotkeysEditor() },
                    { label: qsTr("Reset all shortcuts"), type: "button", buttonText: qsTr("Reset"), confirm: true,
                      action: () => SettingsBackend.resetHotkeys() }
                ] },
                { title: qsTr("Skip Amounts"), rows: [
                    { label: qsTr("Very short skip"), type: "spin", key: "extrashort-jump-size", suffix: qsTr("s") },
                    { label: qsTr("Short skip"), type: "spin", key: "short-jump-size", suffix: qsTr("s") },
                    { label: qsTr("Medium skip"), type: "spin", key: "medium-jump-size", suffix: qsTr("s") },
                    { label: qsTr("Long skip"), type: "spin", key: "long-jump-size", suffix: qsTr("s") }
                ] },
                { title: qsTr("Mouse"), rows: [
                    { label: qsTr("Single click on the video"), type: "dropdown", key: "qt-video-click-action" },
                    { label: qsTr("Double click on the video"), type: "dropdown", key: "qt-video-dblclick-action" },
                    { label: qsTr("Scroll wheel"), type: "dropdown", key: "hotkeys-y-wheel-mode" },
                    { label: qsTr("Horizontal scroll"), type: "dropdown", key: "hotkeys-x-wheel-mode" },
                    { label: qsTr("Reverse scroll direction"), key: "qt-wheel-reverse" }
                ] },
                { title: qsTr("Remotes"), rows: [
                    { label: qsTr("Web remote control"), type: "toggle", key: "extraintf",
                      help: qsTr("Lets you control VLC from a web browser. Restart VLC to apply."),
                      get: () => SettingsBackend.listHas("extraintf", "http"),
                      set: (on) => SettingsBackend.setListItem("extraintf", "http", on) },
                    { label: qsTr("Port"), type: "spin", key: "http-port" }
                ] }
            ]
        },
        {
            id: "playback", name: qsTr("Playback"), title: qsTr("Playback Preferences"), icon: "playback",
            sections: [
                { title: qsTr("Startup"), rows: [
                    { label: qsTr("Continue where you left off"), info: true, type: "dropdown", key: "restore-playback-pos" },
                    { label: qsTr("Start playing as soon as a file opens"), info: true, key: "start-paused", invert: true },
                    { label: qsTr("Default playback speed"), type: "slider", key: "rate", from: 0.25, to: 2, step: 0.25,
                      ticks: [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2].map((v) => ({ value: v, label: String(v) })),
                      format: (v) => v.toFixed(2) + "×" },
                    { label: qsTr("Pause when another app uses audio"), info: true, unavailable: root.unavailableText }
                ] },
                { title: qsTr("Tracks"), rows: [
                    { label: qsTr("Preferred video quality"), info: true, type: "dropdown", key: "preferred-resolution" },
                    { label: qsTr("Preferred menu language"), info: true, type: "dropdown", key: "menu-language",
                      choices: () => root.languageChoices("menu-language") },
                    { label: qsTr("Default audio track"), info: true, type: "spin", key: "audio-track" },
                    { label: qsTr("Default subtitle track"), info: true, type: "spin", key: "sub-track" }
                ] },
                { title: qsTr("Order"), rows: [
                    { label: qsTr("Repeat"), info: true, type: "dropdown", key: "loop",
                      help: qsTr("Repeats the whole playlist or the current item."),
                      choices: [ { value: 0, text: qsTr("Off") }, { value: 1, text: qsTr("All") }, { value: 2, text: qsTr("One") } ],
                      get: () => SettingsBackend.value("repeat") ? 2 : SettingsBackend.value("loop") ? 1 : 0,
                      set: (v) => { SettingsBackend.setValue("loop", v === 1); SettingsBackend.setValue("repeat", v === 2) } },
                    { label: qsTr("Shuffle"), info: true, key: "random" },
                    { label: qsTr("Stop after each item"), info: true, key: "play-and-stop" },
                    { label: qsTr("When playback finishes"), info: true, type: "dropdown", key: "play-and-exit",
                      help: qsTr("What VLC does after the last item of the playlist."),
                      choices: [ { value: 0, text: qsTr("Stop") }, { value: 1, text: qsTr("Pause") }, { value: 2, text: qsTr("Quit") } ],
                      get: () => SettingsBackend.value("play-and-exit") ? 2 : SettingsBackend.value("play-and-pause") ? 1 : 0,
                      set: (v) => { SettingsBackend.setValue("play-and-pause", v === 1); SettingsBackend.setValue("play-and-exit", v === 2) } }
                ] },
                { title: qsTr("Seeking"), rows: [
                    { label: qsTr("Seek precisely"), info: true, key: "input-fast-seek", invert: true },
                    { label: qsTr("Show thumbnail while scrubbing"), info: true, key: "qt-seek-thumbnail" }
                ] },
                { title: qsTr("Files & Discs"), rows: [
                    { label: qsTr("Default optical drive"), info: true, type: "dropdown", key: "dvd",
                      choices: () => root.withCurrent(SettingsBackend.opticalDrives(), "dvd"),
                      set: (v) => { for (const k of ["dvd", "vcd", "cd-audio"]) if (SettingsBackend.exists(k)) SettingsBackend.setValue(k, v) } },
                    { label: qsTr("Repair damaged AVI files"), info: true, type: "dropdown", key: "avi-index" },
                    { label: qsTr("Load matching .mkv files from the same folder"), info: true, key: "mkv-preload-local-dir" }
                ] },
                { title: qsTr("Advanced"), advanced: true, rows: [
                    { label: qsTr("Time-shift buffer folder"), info: true, type: "path", browse: "dir", key: "input-timeshift-path" },
                    { label: qsTr("Time-shift buffer size"), info: true, type: "dropdown", key: "input-timeshift-granularity",
                      choices: () => root.withCurrent([ { value: -1, text: qsTr("Automatic") },
                                                        { value: 10485760, text: qsTr("Small") },
                                                        { value: 52428800, text: qsTr("Medium") },
                                                        { value: 104857600, text: qsTr("Large") } ],
                                                      "input-timeshift-granularity") }
                ] }
            ]
        },
        {
            id: "video", name: qsTr("Video"), title: qsTr("Video Defaults"), icon: "video",
            sections: [
                { title: qsTr("Output"), rows: [
                    { label: qsTr("Enable video"), info: true, key: "video" },
                    { label: qsTr("Start videos in fullscreen"), info: true, key: "fullscreen" },
                    { label: qsTr("Stop the screensaver during playback"), info: true, key: "disable-screensaver" },
                    { label: qsTr("Play video as desktop wallpaper"), info: true, key: "video-wallpaper" }
                ] },
                { title: qsTr("Picture"), rows: [
                    root.pictureRow(qsTr("Hue"), "hue", -180, 180),
                    root.pictureRow(qsTr("Brightness"), "brightness", 0, 2),
                    root.pictureRow(qsTr("Contrast"), "contrast", 0, 2),
                    root.pictureRow(qsTr("Saturation"), "saturation", 0, 3),
                    root.pictureRow(qsTr("Gamma"), "gamma", 0.01, 10),
                    { label: qsTr("Reset picture"), type: "button", buttonText: qsTr("Reset"),
                      enabledWhen: () => SettingsBackend.moduleExists("adjust"),
                      action: () => { for (const k of root.pictureKeys) SettingsBackend.resetValue(k); root.syncAdjustFilter() } }
                ] },
                { title: qsTr("Deinterlacing"), rows: [
                    { label: qsTr("Deinterlacing"), info: true, type: "dropdown", key: "deinterlace" },
                    { label: qsTr("Method"), info: true, type: "dropdown", key: "deinterlace-mode" }
                ] },
                { title: qsTr("Framing"), rows: [
                    { label: qsTr("Aspect ratio"), info: true, type: "dropdown", key: "aspect-ratio",
                      choices: () => root.withCurrent([ { value: "", text: qsTr("Automatic") } ].concat(
                          ["1:1", "4:3", "5:4", "16:9", "16:10", "2.21:1", "2.35:1", "2.39:1"].map((r) => ({ value: r, text: r }))),
                          "aspect-ratio") },
                    { label: qsTr("Crop"), info: true, type: "dropdown", key: "crop",
                      choices: () => root.withCurrent([ { value: "", text: qsTr("None") } ].concat(
                          ["16:10", "16:9", "4:3", "1.85:1", "2.21:1", "2.35:1", "2.39:1", "5:3", "5:4", "1:1"].map((r) => ({ value: r, text: r }))),
                          "crop") },
                    { label: qsTr("Scale video to the window"), info: true, key: "autoscale" },
                    { label: qsTr("Zoom"), info: true, type: "dropdown", key: "zoom",
                      choices: () => root.withCurrent([ { value: 0.25, text: qsTr("Quarter") }, { value: 0.5, text: qsTr("Half") },
                                                        { value: 1, text: qsTr("Fit") }, { value: 2, text: qsTr("Double") } ], "zoom") },
                    { label: qsTr("Position in the window"), info: true, type: "dropdown", key: "align" }
                ] },
                { title: qsTr("Snapshots"), rows: [
                    { label: qsTr("Save to"), info: true, type: "path", browse: "dir", key: "snapshot-path" },
                    { label: qsTr("File name prefix"), info: true, type: "text", key: "snapshot-prefix" },
                    { label: qsTr("Format"), info: true, type: "dropdown", key: "snapshot-format" },
                    { label: qsTr("Size"), info: true, type: "dropdown", key: "snapshot-width",
                      choices: () => {
                          const list = [ { value: "-1x-1", text: qsTr("Same as video") } ]
                          for (const w of [1920, 1280, 640, 320])
                              list.push({ value: w + "x-1", text: qsTr("%1 px wide").arg(w) })
                          const cur = SettingsBackend.value("snapshot-width") + "x" + SettingsBackend.value("snapshot-height")
                          if (!list.some((c) => c.value === cur))
                              list.push({ value: cur, text: cur.replace(/-1/g, qsTr("auto")) })
                          return list
                      },
                      get: () => SettingsBackend.value("snapshot-width") + "x" + SettingsBackend.value("snapshot-height"),
                      set: (v) => { const p = v.split("x"); SettingsBackend.setValue("snapshot-width", parseInt(p[0])); SettingsBackend.setValue("snapshot-height", parseInt(p[1])) } },
                    { label: qsTr("Number files sequentially"), info: true, key: "snapshot-sequential" },
                    { label: qsTr("Show a preview after capture"), info: true, key: "snapshot-preview" }
                ] },
                { title: qsTr("Advanced"), advanced: true, rows: [
                    { label: qsTr("Custom aspect ratios"), info: true, type: "text", key: "custom-aspect-ratios" },
                    { label: qsTr("Custom crop ratios"), info: true, type: "text", key: "custom-crop-ratios" },
                    { label: qsTr("Monitor pixel aspect ratio"), info: true, type: "text", key: "monitor-par", placeholder: "1:1" }
                ] }
            ]
        },
        {
            id: "audio", name: qsTr("Audio"), title: qsTr("Audio Defaults"), icon: "audio",
            sections: [
                { title: qsTr("Output"), rows: [
                    { label: qsTr("Enable audio"), info: true, key: "audio" },
                    { label: qsTr("Output device"), info: true, type: "dropdown",
                      key: SettingsBackend.exists("mmdevice-audio-device") ? "mmdevice-audio-device" : "aout" },
                    { label: qsTr("Speaker setup"), info: true, type: "dropdown", key: "mix-mode" }
                ] },
                { title: qsTr("Volume"), rows: [
                    { label: qsTr("Maximum volume"), type: "slider", key: "qt-max-volume", step: 5,
                      ticks: [ { value: 100, label: "100%" }, { value: 200, label: "200%" }, { value: 300, label: "300%" } ],
                      format: (v) => Math.round(v) + "%" },
                    { label: qsTr("Startup volume"), info: true, type: "startupVolume", key: "volume-save" },
                    { label: qsTr("Volume step"), info: true, type: "spin", key: "volume-step", decimals: 1 }
                ] },
                { title: qsTr("Loudness"), rows: [
                    root.listToggle(qsTr("Normalize loudness"), "audio-filter", "normvol",
                                    { help: qsTr("Evens out the volume between loud and quiet parts.") }),
                    { label: qsTr("Target level"), info: true, type: "spin", key: "norm-max-level", decimals: 1, step: 0.5 },
                    { label: qsTr("Night mode"), info: true, unavailable: root.unavailableText },
                    { label: qsTr("Replay gain"), info: true, type: "dropdown", key: "audio-replay-gain-mode" },
                    { label: qsTr("Replay gain preamp"), info: true, type: "spin", key: "audio-replay-gain-preamp",
                      decimals: 1, step: 0.5, suffix: qsTr("dB") }
                ] },
                { title: qsTr("Effects"), rows: [
                    root.listToggle(qsTr("Equalizer"), "audio-filter", "equalizer"),
                    { label: qsTr("Equalizer preset"), info: true, type: "dropdown", key: "equalizer-preset" },
                    { label: qsTr("Two-pass"), info: true, key: "equalizer-2pass" },
                    root.listToggle(qsTr("Spatial audio"), "audio-filter", "spatializer"),
                    { label: qsTr("Spatial audio mode"), info: true, type: "dropdown", key: "spatialaudio-headphones",
                      choices: [ { value: false, text: qsTr("Speakers") }, { value: true, text: qsTr("Headphone virtualization") } ] },
                    root.listToggle(qsTr("Stereo widening"), "audio-filter", "stereo_widen"),
                    root.listToggle(qsTr("Compressor"), "audio-filter", "compressor"),
                    { label: qsTr("Pitch shift"), info: true, type: "spin", key: "pitch-shift", decimals: 2, step: 0.5 },
                    root.listToggle(qsTr("Chorus/flanger"), "audio-filter", "chorus_flanger"),
                    root.listToggle(qsTr("Karaoke"), "audio-filter", "karaoke")
                ] },
                { title: qsTr("Tracks"), rows: [
                    { label: qsTr("Preferred audio language"), info: true, type: "dropdown", key: "audio-language",
                      choices: () => root.languageChoices("audio-language") },
                    { label: qsTr("Audio delay"), info: true, type: "spin", key: "audio-desync", scale: 1000,
                      decimals: 2, step: 0.05, suffix: qsTr("s") }
                ] },
                { title: qsTr("Visualization"), rows: [
                    { label: qsTr("Visualizer"), info: true, type: "dropdown", key: "audio-visual" }
                ] },
                { title: qsTr("Advanced"), advanced: true, rows: [
                    { label: qsTr("Pass compressed audio to the receiver"), info: true, key: "spdif" },
                    { label: qsTr("Detect Dolby Surround"), info: true, type: "dropdown", key: "force-dolby-surround" },
                    { label: qsTr("Resampling quality"), info: true, type: "dropdown", key: "audio-resampler" },
                    { label: qsTr("Media role"), info: true, type: "dropdown", key: "role" },
                    { label: qsTr("Visualization size"), info: true, type: "dropdown", key: "effect-width",
                      choices: () => {
                          const list = [ [400, 250], [800, 500], [1280, 800], [1920, 1080] ].map(
                              (s) => ({ value: s[0] + "x" + s[1], text: s[0] + " × " + s[1] }))
                          const cur = SettingsBackend.value("effect-width") + "x" + SettingsBackend.value("effect-height")
                          if (!list.some((c) => c.value === cur))
                              list.push({ value: cur, text: cur.replace("x", " × ") })
                          return list
                      },
                      get: () => SettingsBackend.value("effect-width") + "x" + SettingsBackend.value("effect-height"),
                      set: (v) => { const p = v.split("x"); SettingsBackend.setValue("effect-width", parseInt(p[0])); SettingsBackend.setValue("effect-height", parseInt(p[1])) } }
                ] }
            ]
        },
        {
            id: "subtitles", name: qsTr("Subtitles"), title: qsTr("Subtitle Defaults"), icon: "subtitles",
            sections: [
                { title: qsTr("Tracks & Languages"), rows: [
                    { label: qsTr("Enable subtitles"), info: true, key: "spu" },
                    { label: qsTr("Preferred language"), info: true, type: "dropdown", key: "sub-language",
                      choices: () => root.languageChoices("sub-language") },
                    { label: qsTr("Text encoding"), info: true, type: "dropdown", key: "subsdec-encoding" }
                ] },
                { title: qsTr("Loading Subtitles"), rows: [
                    { label: qsTr("Load subtitle files automatically"), info: true, key: "sub-autodetect-file" },
                    { label: qsTr("File name matching"), info: true, type: "dropdown", key: "sub-autodetect-fuzzy" }
                ] },
                { title: qsTr("Appearance"), rows: [
                    { label: qsTr("Font"), info: true, type: "text", key: "freetype-font", placeholder: qsTr("System, sans-serif") },
                    { label: qsTr("Size values"), info: true, type: "segmented", key: "freetype-fontsize",
                      help: qsTr("Relative sizes follow the video size. Fixed sizes are in pixels."),
                      choices: [ { value: 0, text: qsTr("Relative") }, { value: 1, text: qsTr("Fixed") } ],
                      get: () => Number(SettingsBackend.value("freetype-fontsize")) > 0 ? 1 : 0,
                      set: (v) => SettingsBackend.setValue("freetype-fontsize", v === 1 ? 24 : 0) },
                    { label: qsTr("Font size"), type: "dropdown", key: "freetype-rel-fontsize",
                      enabledWhen: () => Number(SettingsBackend.value("freetype-fontsize")) === 0 },
                    { label: qsTr("Bold"), key: "freetype-bold" },
                    { label: qsTr("Text color"), type: "color", key: "freetype-color" },
                    { label: qsTr("Text opacity"), type: "slider", key: "freetype-opacity", from: 0, to: 100, step: 1,
                      ticks: root.percentTicks, format: (v) => Math.round(v) + "%",
                      get: () => Number(SettingsBackend.value("freetype-opacity")) * 100 / 255,
                      set: (v) => SettingsBackend.setValue("freetype-opacity", Math.round(v * 2.55)) },
                    { label: qsTr("Outline thickness"), type: "dropdown", key: "freetype-outline-thickness" },
                    { label: qsTr("Outline color"), type: "color", key: "freetype-outline-color" },
                    { label: qsTr("Shadow"), key: "freetype-shadow-opacity",
                      get: () => Number(SettingsBackend.value("freetype-shadow-opacity")) > 0,
                      set: (on) => SettingsBackend.setValue("freetype-shadow-opacity", on ? 128 : 0) },
                    { label: qsTr("Shadow color"), type: "color", key: "freetype-shadow-color" },
                    { label: qsTr("Shadow distance"), type: "dropdown", key: "freetype-shadow-distance",
                      choices: () => root.withCurrent([ { value: 0.03, text: qsTr("Small") }, { value: 0.06, text: qsTr("Medium") },
                                                        { value: 0.12, text: qsTr("Large") } ], "freetype-shadow-distance") },
                    { label: qsTr("Background"), type: "dropdown", key: "freetype-background-opacity",
                      choices: [ { value: 0, text: qsTr("None") }, { value: 1, text: qsTr("Box") } ],
                      get: () => Number(SettingsBackend.value("freetype-background-opacity")) > 0 ? 1 : 0,
                      set: (v) => SettingsBackend.setValue("freetype-background-opacity", v === 1 ? 128 : 0) },
                    { label: qsTr("Background color"), type: "color", key: "freetype-background-color" },
                    { label: qsTr("Background opacity"), type: "slider", key: "freetype-background-opacity", from: 0, to: 100, step: 1,
                      ticks: root.percentTicks, format: (v) => Math.round(v) + "%",
                      get: () => Number(SettingsBackend.value("freetype-background-opacity")) * 100 / 255,
                      set: (v) => SettingsBackend.setValue("freetype-background-opacity", Math.round(v * 2.55)) },
                    { label: qsTr("Vertical position"), type: "dropdown", key: "sub-margin",
                      choices: () => root.withCurrent([ { value: 0, text: qsTr("Bottom") }, { value: 50, text: qsTr("Raised") },
                                                        { value: 100, text: qsTr("High") } ], "sub-margin") }
                ] },
                { title: qsTr("Timing"), rows: [
                    // sub-delay is in 1/10 s
                    { label: qsTr("Subtitle delay"), type: "slider", key: "sub-delay", scale: 10, from: -5, to: 5, step: 0.1,
                      ticks: [ { value: -5, label: qsTr("-5 s") }, { value: 0, label: qsTr("0 s") }, { value: 5, label: qsTr("+5 s") } ],
                      format: (v) => qsTr("%1 s").arg(v.toFixed(1)) }
                ] },
                { title: qsTr("On-Screen Messages"), rows: [
                    { label: qsTr("Show feedback for shortcuts"), info: true, key: "osd" },
                    { label: qsTr("Show feedback for"), type: "slider", key: "qt-osd-duration", from: 0.5, to: 5, step: 0.5,
                      ticks: [ { value: 0.5, label: qsTr("0.5 s") }, { value: 5, label: qsTr("5 s") } ],
                      format: (v) => qsTr("%1 s").arg(v) },
                    { label: qsTr("Show filename when a video starts"), info: true, key: "video-title-show" },
                    { label: qsTr("Show filename for"), type: "slider", key: "video-title-timeout", scale: 1000, from: 1, to: 10, step: 0.5,
                      ticks: [ { value: 1, label: qsTr("1 s") }, { value: 10, label: qsTr("10 s") } ],
                      format: (v) => qsTr("%1 s").arg(v) }
                ] },
                { title: qsTr("Advanced"), advanced: true, rows: [
                    { label: qsTr("Load subtitles from these folders"), info: true, type: "text", key: "sub-autodetect-path" },
                    { label: qsTr("Ignore styling in ASS and SSA subtitles"), info: true, unavailable: root.unavailableText },
                    { label: qsTr("Shadow angle"), info: true, type: "spin", key: "freetype-shadow-angle", decimals: 0, suffix: "°" },
                    { label: qsTr("Text direction"), info: true, type: "dropdown", key: "freetype-text-direction" },
                    { label: qsTr("Monospace font"), info: true, type: "text", key: "freetype-monofont",
                      placeholder: qsTr("System monospace") }
                ] }
            ]
        },
        {
            id: "library", name: qsTr("Library"), title: qsTr("Playlists, Folders & Files"), icon: "library",
            sections: [
                { title: qsTr("Opening Files"), rows: [
                    { label: qsTr("Only allow one VLC window"), info: true, key: "one-instance" },
                    { label: qsTr("Apply to files opened from the file manager"), info: true, key: "one-instance-when-started-from-file" },
                    { label: qsTr("Add to the playlist instead of replacing it"), info: true, key: "playlist-enqueue" },
                    { label: qsTr("When opening a folder"), info: true, type: "dropdown", key: "recursive" },
                    { label: qsTr("Show hidden files"), info: true, key: "show-hiddenfiles" }
                ] },
                { title: qsTr("Metadata & Artwork"), rows: [
                    { label: qsTr("Fetch titles and artwork"), info: true, type: "dropdown", key: "metadata-network-access",
                      choices: [ { value: false, text: qsTr("From the file only") },
                                 { value: true, text: qsTr("From the file and the internet") } ] },
                    { label: qsTr("Use the media library"), info: true, key: "media-library" }
                ] }
            ]
        },
        {
            id: "network", name: qsTr("Network"), title: qsTr("Network Connections & Security"), icon: "network",
            sections: [
                { title: qsTr("Buffering"), rows: [
                    { label: qsTr("Buffering"), info: true, type: "dropdown", key: "network-caching",
                      help: qsTr("Sets the four buffer sizes below at once. Larger buffers play more smoothly but start later."),
                      choices: () => {
                          const list = root.cachingPresets.map((p) => ({ value: p.value, text: p.text }))
                          return list.concat([ { value: -1, text: qsTr("Custom") } ])
                      },
                      get: () => {
                          const cur = root.cachingKeys.map((k) => Number(SettingsBackend.value(k)))
                          const p = root.cachingPresets.find((p) => p.values.every((v, i) => v === cur[i]))
                          return p ? p.value : -1
                      },
                      set: (v) => {
                          const p = root.cachingPresets.find((p) => p.value === v)
                          if (p)
                              root.cachingKeys.forEach((k, i) => SettingsBackend.setValue(k, p.values[i]))
                      } },
                    { label: qsTr("Local files"), type: "spin", key: "file-caching", step: 100, suffix: qsTr("ms") },
                    { label: qsTr("Discs"), type: "spin", key: "disc-caching", step: 100, suffix: qsTr("ms") },
                    { label: qsTr("Network streams"), type: "spin", key: "network-caching", step: 100, suffix: qsTr("ms") },
                    { label: qsTr("Live capture"), type: "spin", key: "live-caching", step: 100, suffix: qsTr("ms") }
                ] },
                { title: qsTr("Proxy"), rows: [
                    { label: qsTr("HTTP proxy"), info: true, type: "text", key: "http-proxy", placeholder: qsTr("System proxy") },
                    { label: qsTr("HTTP proxy password"), info: true, type: "password", key: "http-proxy-pwd" }
                ] },
                { title: qsTr("Security"), rows: [
                    { label: qsTr("Verify certificates against the system trust store"), info: true, key: "gnutls-system-trust" },
                    { label: qsTr("Cipher preference"), info: true, type: "dropdown", key: "gnutls-priorities" }
                ] }
            ]
        },
        {
            id: "performance", name: qsTr("Performance"), title: qsTr("Performance Settings"), icon: "performance",
            sections: [
                { title: qsTr("Decoding"), rows: [
                    { label: qsTr("Hardware-accelerated decoding"), info: true, type: "dropdown", key: "hw-dec",
                      choices: [ { value: true, text: qsTr("Automatic") }, { value: false, text: qsTr("Off") } ] },
                    { label: qsTr("Video post-processing"), info: true, type: "dropdown", key: "postproc-q",
                      choices: [ { value: 0, text: qsTr("Off") } ].concat([1, 2, 3, 4, 5].map((q) => ({ value: q, text: String(q) })))
                                .concat([ { value: 6, text: qsTr("6 (best)") } ]) },
                    { label: qsTr("Skip the H.264 loop filter"), info: true, type: "dropdown", key: "avcodec-skiploopfilter" },
                    { label: qsTr("Decoding threads"), info: true, type: "spin", key: "avcodec-threads" }
                ] },
                { title: qsTr("Smooth Playback"), rows: [
                    { label: qsTr("Drop frames when the system can't keep up"), key: "drop-late-frames" },
                    { label: qsTr("Give VLC real-time priority"), key: "rt-priority" },
                    { label: qsTr("Process priority"), info: true, type: "spin", key: "rt-offset" },
                    { label: qsTr("Rescan plugins"), type: "button", wide: true, buttonText: qsTr("Rescan"),
                      unavailable: qsTr("VLC rescans its plugins automatically when they change.") }
                ] },
                { title: qsTr("Developer"), advanced: true, developer: true, rows: [
                    { label: qsTr("Encoder"), info: true, type: "dropdown", key: "encoder" },
                    { label: qsTr("Decoder"), info: true, type: "dropdown", key: "codec" },
                    { label: qsTr("Clock synchronisation"), info: true, type: "dropdown", key: "clock-synchro" },
                    { label: qsTr("Clock jitter"), info: true, type: "spin", key: "clock-jitter", suffix: qsTr("ms") },
                    { label: qsTr("Clock reference averaging"), info: true, type: "spin", unavailable: root.unavailableText }
                ] }
            ]
        },
        {
            id: "recording", name: qsTr("Recording"), title: qsTr("Recording, Casting & Streaming Out"), icon: "recording",
            sections: [
                { title: qsTr("Recording"), rows: [
                    { label: qsTr("Save recordings to"), info: true, type: "path", browse: "dir", key: "input-record-path",
                      placeholder: qsTr("~/Videos") },
                    { label: qsTr("Record without re-encoding when possible"), get: () => true,
                      unavailable: qsTr("VLC always records the original streams without re-encoding.") }
                ] },
                { title: qsTr("Casting"), rows: [
                    { label: qsTr("Discover cast devices"), unavailable: root.unavailableText },
                    { label: qsTr("Cast quality"), info: true, type: "dropdown", key: "sout-chromecast-conversion-quality" }
                ] },
                { title: qsTr("Streaming"), rows: [
                    { label: qsTr("Play locally while streaming"), key: "sout-display" },
                    { label: qsTr("Include audio"), key: "sout-audio" },
                    { label: qsTr("Include video"), key: "sout-video" },
                    { label: qsTr("Include subtitles"), key: "sout-spu" },
                    { label: qsTr("Encoding preset"), info: true, type: "dropdown", key: "sout-x264-preset" },
                    { label: qsTr("Tuning"), info: true, type: "dropdown", key: "sout-x264-tune" }
                ] }
            ]
        },
        {
            id: "extensions", name: qsTr("Extensions"), title: qsTr("Add-ons & Scripts"), icon: "extensions",
            sections: [
                { title: qsTr("Add-ons"), rows: [
                    { label: qsTr("Find more extensions"), type: "addons", searchOnly: true },
                    { label: qsTr("Load add-ons on startup"), key: "qt-autoload-extensions" }
                ] }
            ]
        }
    ]
}
