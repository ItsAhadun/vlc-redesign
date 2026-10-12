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
import VLC.Util

// Sidebar category row ("setting category", design/SPEC.md 3.7): 188x40,
// icon 24 at x 10, label at x 50. Selected: BG/A1, accent icon, FG/1 label.
T.ItemDelegate {
    id: control

    readonly property var pal: VLCStyle.palette
    property string iconName
    property bool selected: false

    implicitWidth: VLCStyle.settingsCategory_width
    implicitHeight: VLCStyle.settingsCategory_height
    focusPolicy: Qt.StrongFocus
    padding: 0

    Accessible.role: Accessible.PageTab
    Accessible.name: text
    Accessible.selected: selected

    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()

    readonly property color iconColor: selected ? pal.accentMain : (hovered ? pal.fg2 : pal.fgA2)

    background: Rectangle {
        radius: VLCStyle.radius_small
        color: control.selected ? control.pal.bgA1 : (control.hovered ? control.pal.hoverOverlay : "transparent")
        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: control.pal.accentMain
    }

    contentItem: Item {
        Image {
            x: VLCStyle.space_10
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.icon_normal
            height: VLCStyle.icon_normal
            sourceSize: Qt.size(width, height)
            source: control.iconName === "" ? ""
                  : SVGColorImage.colorize("qrc:///settings/" + control.iconName + ".svg")
                                 .color1(control.iconColor).uri()
        }

        Text {
            x: VLCStyle.dp(50, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - VLCStyle.space_8
            text: control.text
            font.pixelSize: VLCStyle.fontSize_body
            color: control.selected ? (control.pal.isDark ? control.pal.fg1 : control.pal.fgB1) : (control.hovered ? (control.pal.isDark ? control.pal.fg2 : control.pal.fgB1) : control.pal.fgA2)
            elide: Text.ElideRight
        }
    }
}
