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

// Settings section: header (16px FG/2 in a 39 px slot) followed by its rows.
Column {
    id: root

    property string title
    property var rows: []
    // optional action on the header (search results: go to the page)
    signal headerClicked()
    property bool headerClickable: false

    readonly property var pal: VLCStyle.palette

    width: VLCStyle.dp(784, VLCStyle.scale)

    Item {
        width: parent.width
        height: VLCStyle.dp(39, VLCStyle.scale)

        Text {
            id: header

            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            font.pixelSize: VLCStyle.fontSize_title
            font.weight: VLCStyle.fontWeight_heading
            color: headerMouse.containsMouse ? root.pal.accentMain : (root.pal.isDark ? root.pal.fg2 : root.pal.fgB1)
            Accessible.role: Accessible.Heading
            Accessible.name: text
        }

        MouseArea {
            id: headerMouse
            visible: root.headerClickable
            anchors.fill: header
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.headerClicked()
        }
    }

    Repeater {
        model: root.rows

        delegate: SettingsRow {
            required property var modelData
            row: modelData
            width: root.width
        }
    }
}
