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

// Accent color picker (design/SPEC.md 1.2 / 2.3): the 9 accent presets in a
// segmented track, the selected cell is BG/Accent Bright. Applies live
// through MainCtx (persisted in "qt-accent-color").
T.Control {
    id: control

    readonly property var pal: VLCStyle.palette
    readonly property var presets: MainCtx.accentPresets
    readonly property real swatchSize: VLCStyle.dp(20, VLCStyle.scale)

    implicitWidth: VLCStyle.settingsRow_controlWidth
    implicitHeight: VLCStyle.dropdown_height

    focusPolicy: Qt.StrongFocus
    padding: 0

    Accessible.role: Accessible.List
    Accessible.name: qsTr("Accent color")

    Keys.onLeftPressed: (event) => {
        if (MainCtx.accentIndex > 0)
            MainCtx.accentIndex = MainCtx.accentIndex - 1
        else
            event.accepted = false
    }
    Keys.onRightPressed: (event) => {
        if (MainCtx.accentIndex < presets.length - 1)
            MainCtx.accentIndex = MainCtx.accentIndex + 1
        else
            event.accepted = false
    }

    Rectangle {
        anchors.fill: parent
        color: control.pal.bgB2
        radius: VLCStyle.radius_medium
        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: control.pal.accentMain
    }

    Row {
        anchors.fill: parent
        anchors.margins: VLCStyle.space_2
        spacing: VLCStyle.space_2

        Repeater {
            model: control.presets

            delegate: Rectangle {
                id: cell

                required property int index
                required property color modelData
                readonly property bool selected: index === MainCtx.accentIndex

                width: (control.width - 2 * VLCStyle.space_2 - (control.presets.length - 1) * VLCStyle.space_2) / control.presets.length
                height: parent.height
                radius: VLCStyle.radius_small
                color: selected ? control.pal.bgAccentBright
                                : (mouse.containsMouse ? control.pal.hoverOverlay : "transparent")

                Accessible.role: Accessible.ListItem
                Accessible.name: modelData.toString()
                Accessible.selected: selected

                Rectangle {
                    anchors.centerIn: parent
                    width: control.swatchSize
                    height: control.swatchSize
                    color: cell.modelData
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        control.forceActiveFocus(Qt.MouseFocusReason)
                        MainCtx.accentIndex = cell.index
                    }
                }
            }
        }
    }
}
