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

// Search field of the settings header (design/SPEC.md 2.3): 200x34, BG/A5,
// search icon at (8, 5), placeholder "Search" in FG/A4.
T.TextField {
    id: control

    readonly property var pal: VLCStyle.palette

    implicitWidth: VLCStyle.dp(200, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(34, VLCStyle.scale)

    leftPadding: VLCStyle.space_8 + VLCStyle.icon_normal + VLCStyle.space_8
    rightPadding: clearButton.visible ? clearButton.width + VLCStyle.space_4 : VLCStyle.space_8
    verticalAlignment: TextInput.AlignVCenter

    font.pixelSize: VLCStyle.fontSize_body
    color: pal.fgA2
    placeholderText: qsTr("Search")
    placeholderTextColor: pal.fgA4
    selectionColor: pal.bgAccentBright
    selectByMouse: true

    Accessible.role: Accessible.EditableText
    Accessible.name: qsTr("Search settings")

    Keys.onEscapePressed: (event) => {
        if (text !== "")
            text = ""
        else
            event.accepted = false
    }

    background: Rectangle {
        color: control.pal.bgA5
        radius: VLCStyle.radius_medium
        border.width: control.activeFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: control.pal.accentDim

        Text {
            x: control.leftPadding
            width: parent.width - control.leftPadding - control.rightPadding
            anchors.verticalCenter: parent.verticalCenter
            visible: control.text === "" && !control.preeditText
            text: control.placeholderText
            font: control.font
            color: control.placeholderTextColor
            elide: Text.ElideRight
        }

        Widgets.IconLabel {
            x: VLCStyle.space_8
            anchors.verticalCenter: parent.verticalCenter
            text: VLCIcons.search
            font.pixelSize: VLCStyle.icon_normal
            color: control.activeFocus ? control.pal.fgA2 : control.pal.fgA3
        }

        Widgets.IconLabel {
            id: clearButton

            visible: control.text !== ""
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.space_6
            anchors.verticalCenter: parent.verticalCenter
            text: VLCIcons.close
            font.pixelSize: VLCStyle.icon_small
            color: clearMouse.containsMouse ? control.pal.fgA2 : control.pal.fgA3

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                anchors.margins: -VLCStyle.space_4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: control.text = ""
            }
        }
    }
}
