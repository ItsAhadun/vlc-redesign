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

// Button (design/SPEC.md 3.1): BG/A4, r4, label 14px FG/A2; 100x32 by default.
T.Button {
    id: control

    readonly property var pal: VLCStyle.palette
    // accent (primary) variant
    property bool primary: false

    implicitWidth: Math.max(VLCStyle.dialogButton_width, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: VLCStyle.dialogButton_height

    leftPadding: VLCStyle.space_12
    rightPadding: VLCStyle.space_12
    focusPolicy: Qt.StrongFocus

    font.pixelSize: VLCStyle.fontSize_body
    font.weight: VLCStyle.fontWeight_medium

    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()

    contentItem: Text {
        text: control.text
        font: control.font
        color: !control.enabled ? control.pal.fgA4
             : control.primary ? control.pal.fgOnAccent
             : (control.hovered ? (control.pal.isDark ? control.pal.fg2 : control.pal.fgB1) : control.pal.fgA2)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: VLCStyle.radius_small
        color: control.primary ? (control.pressed ? control.pal.accentDim : control.hovered ? control.pal.accentBright : control.pal.accentMain)
                               : (control.pressed ? control.pal.bgA2 : control.hovered ? control.pal.bgA1 : control.pal.bgA4)
        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: control.pal.accentMain
    }
}
