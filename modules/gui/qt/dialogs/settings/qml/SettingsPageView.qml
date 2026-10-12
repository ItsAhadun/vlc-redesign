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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Dialogs

// Scrollable content of the settings window: one page (sections, the
// "Advanced Options" bar and, when expanded, the advanced sections), or the
// search results across every page when `query` is not empty.
FocusScope {
    id: root

    required property var pages      // SettingsPages
    property string pageId: "general"
    property string query: ""
    // page id -> expanded
    property var expandedPages: ({})

    signal pageRequested(string pageId)

    readonly property var pal: VLCStyle.palette
    readonly property var page: pages.page(pageId)
    readonly property bool developerMode: { SettingsBackend.revision; return !!SettingsBackend.value("qt-developer-mode") }
    readonly property bool searching: query.trim() !== ""
    readonly property bool hasAdvanced: !!page && page.sections.some((s) => s.advanced && (!s.developer || developerMode))
    readonly property bool expanded: !!expandedPages[pageId]

    readonly property var allPrefsRow: ({
        label: qsTr("All VLC preferences"), type: "button", buttonText: qsTr("Open"), info: true,
        help: qsTr("Opens the classic preferences window with every VLC option."),
        action: () => SettingsBackend.openClassicPreferences()
    })

    function sectionVisible(s, advanced) {
        if (!!s.advanced !== advanced)
            return false
        return !s.developer || developerMode
    }

    // move the keyboard focus to the first control of the page
    function focusFirst() {
        const item = content.nextItemInFocusChain(true)
        if (item)
            item.forceActiveFocus(Qt.TabFocusReason)
    }

    function toggleAdvanced() {
        if (!hasAdvanced) {
            SettingsBackend.openClassicPreferences()
            return
        }
        const e = Object.assign({}, expandedPages)
        e[pageId] = !e[pageId]
        expandedPages = e
    }

    // search results: [{ page, rows }]
    readonly property var results: {
        if (!searching)
            return []
        SettingsBackend.revision
        const q = query.trim().toLowerCase()
        const out = []
        for (const p of pages.pages) {
            const rows = []
            for (const s of p.sections) {
                if (s.developer && !developerMode)
                    continue
                const sectionMatch = s.title.toLowerCase().includes(q)
                for (const r of s.rows)
                    if (sectionMatch || r.label.toLowerCase().includes(q))
                        rows.push(r)
            }
            if (p.name.toLowerCase().includes(q) && rows.length === 0)
                for (const s of p.sections)
                    if (!s.advanced)
                        rows.push(...s.rows)
            if (rows.length > 0)
                out.push({ page: p, rows: rows })
        }
        return out
    }

    onPageIdChanged: flickable.contentY = 0
    onQueryChanged: flickable.contentY = 0

    // keep the focused control visible when navigating with the keyboard
    function ensureVisible(item) {
        if (!item || !flickable.contentItem)
            return
        let p = item
        while (p && p !== flickable.contentItem)
            p = p.parent
        if (!p)
            return
        const pos = item.mapToItem(flickable.contentItem, 0, 0)
        const margin = VLCStyle.space_20
        if (pos.y < flickable.contentY + margin)
            flickable.contentY = Math.max(0, pos.y - margin)
        else if (pos.y + item.height > flickable.contentY + flickable.height - margin)
            flickable.contentY = Math.min(flickable.contentHeight - flickable.height,
                                          pos.y + item.height - flickable.height + margin)
    }

    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() {
            const w = root.Window.window
            if (w && w.activeFocusItem)
                root.ensureVisible(w.activeFocusItem)
        }
    }

    Flickable {
        id: flickable

        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight + content.y + VLCStyle.space_24
        boundsBehavior: Flickable.StopAtBounds
        focus: true

        T.ScrollBar.vertical: Widgets.ScrollBarExt { }

        Column {
            id: content

            x: VLCStyle.space_24
            y: VLCStyle.space_20
            width: VLCStyle.dp(784, VLCStyle.scale)
            spacing: VLCStyle.space_20

            // -- page -------------------------------------------------------
            Repeater {
                model: !root.searching && root.page ? root.page.sections.filter((s) => root.sectionVisible(s, false)) : []

                delegate: SettingsSection {
                    required property var modelData
                    title: modelData.title
                    rows: modelData.rows
                }
            }

            SettingsAdvancedBar {
                visible: !root.searching && !!root.page && !root.page.noAdvancedBar
                expanded: root.expanded && root.hasAdvanced
                onClicked: root.toggleAdvanced()
            }

            Repeater {
                model: !root.searching && root.page && root.expanded ? root.page.sections.filter((s) => root.sectionVisible(s, true)) : []

                delegate: SettingsSection {
                    required property var modelData
                    title: modelData.title
                    rows: modelData.rows
                }
            }

            SettingsRow {
                visible: !root.searching && root.expanded && root.hasAdvanced
                width: content.width
                row: root.allPrefsRow
            }

            // -- search results ---------------------------------------------
            Repeater {
                model: root.results

                delegate: SettingsSection {
                    required property var modelData
                    title: modelData.page.name
                    rows: modelData.rows
                    headerClickable: true
                    onHeaderClicked: root.pageRequested(modelData.page.id)
                }
            }

            Column {
                visible: root.searching && root.results.length === 0
                width: content.width
                spacing: VLCStyle.space_10
                topPadding: VLCStyle.space_20

                Text {
                    width: parent.width
                    text: qsTr("No settings match “%1”").arg(root.query.trim())
                    font.pixelSize: VLCStyle.fontSize_title
                    font.weight: VLCStyle.fontWeight_heading
                    color: root.pal.isDark ? root.pal.fg2 : root.pal.fgB1
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    text: qsTr("Try a different word, or look through every option in the full preferences.")
                    font.pixelSize: VLCStyle.fontSize_body
                    color: root.pal.fgA2
                    wrapMode: Text.Wrap
                }

                Item { width: 1; height: VLCStyle.space_4 }

                SettingsButton {
                    text: qsTr("Open all VLC preferences")
                    onClicked: SettingsBackend.openClassicPreferences()
                }
            }
        }
    }
}
