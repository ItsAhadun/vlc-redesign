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

// "Advanced Options >" bar (design/SPEC.md 2.3): 784x38, BG/A4, r4, centered
// label + chevron. `expanded` turns the chevron down.
T.AbstractButton {
    id: control

    readonly property var pal: VLCStyle.palette
    property bool expanded: false

    implicitWidth: VLCStyle.dp(784, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(38, VLCStyle.scale)
    focusPolicy: Qt.StrongFocus
    text: qsTr("Advanced Options")

    Accessible.role: Accessible.Button
    Accessible.name: text

    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()

    background: Rectangle {
        radius: VLCStyle.radius_small
        color: control.pressed ? control.pal.bgA2 : control.hovered ? control.pal.bgA1 : control.pal.bgA4
        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: control.pal.accentMain
    }

    contentItem: Item {
        Row {
            anchors.centerIn: parent
            spacing: VLCStyle.space_10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: control.text
                font.pixelSize: VLCStyle.fontSize_body
                color: control.hovered ? (control.pal.isDark ? control.pal.fg2 : control.pal.fgB1) : control.pal.fgA2
            }

            Widgets.IconLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: VLCIcons.ic_fluent_chevron_right_24
                font.pixelSize: VLCStyle.icon_normal
                color: control.hovered ? (control.pal.isDark ? control.pal.fg2 : control.pal.fgB1) : control.pal.fgA2
                rotation: control.expanded ? 90 : 0

                Behavior on rotation {
                    NumberAnimation { duration: VLCStyle.duration_short }
                }
            }
        }
    }
}
