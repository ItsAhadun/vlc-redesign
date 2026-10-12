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

// Toggle (design/SPEC.md 3.2): 68x32 ON/OFF pill, accent when ON
T.AbstractButton {
    id: control

    readonly property var pal: VLCStyle.palette
    readonly property real inset: VLCStyle.dp(3, VLCStyle.scale)
    readonly property real wellWidth: VLCStyle.dp(33, VLCStyle.scale)
    readonly property real knobWidth: VLCStyle.dp(26, VLCStyle.scale)

    checkable: true
    focusPolicy: Qt.StrongFocus
    padding: 0

    implicitWidth: VLCStyle.toggle_width
    implicitHeight: VLCStyle.toggle_height

    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: checked

    Keys.onReturnPressed: toggle()
    Keys.onEnterPressed: toggle()

    background: Rectangle {
        color: control.pal.bgB2
        radius: VLCStyle.radius_medium
        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: control.pal.accentMain
    }

    contentItem: Item {
        Rectangle {
            id: well

            x: control.checked ? control.inset : control.width - control.inset - width
            y: control.inset
            width: control.wellWidth
            height: control.height - 2 * control.inset
            radius: VLCStyle.radius_xsmall
            color: control.checked ? control.pal.bgAccentBright : control.pal.bgA4

            Text {
                anchors.centerIn: parent
                text: control.checked ? qsTr("ON") : qsTr("OFF")
                font.pixelSize: VLCStyle.fontSize_caption
                color: control.checked ? control.pal.accentMain : control.pal.fgA3
            }
        }

        Rectangle {
            x: control.checked ? control.width - control.inset - width : control.inset
            y: control.inset
            width: control.knobWidth
            height: control.height - 2 * control.inset
            radius: VLCStyle.radius_xsmall
            color: control.checked ? control.pal.accentDim
                                   : (control.hovered ? Qt.lighter(control.pal.fgA4, 1.25) : control.pal.fgA4)

            Behavior on x {
                enabled: control.visible
                NumberAnimation { duration: VLCStyle.duration_short; easing.type: Easing.OutQuad }
            }
        }
    }
}
