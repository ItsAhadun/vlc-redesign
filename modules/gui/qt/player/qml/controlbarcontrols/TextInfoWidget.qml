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
import QtQuick.Layouts

import VLC.Style

// base of the text widgets of the control bar (file / artist / folder /
// playlist name)
T.Label {
    id: root

    property bool paintOnly: false
    property string placeholder: ""

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // Layout.minimumWidth > 0: the control can shrink (see ControlRepeater)
    Layout.minimumWidth: VLCStyle.dp(48, VLCStyle.scale)

    width: Math.min(implicitWidth, VLCStyle.dp(240, VLCStyle.scale))
    implicitHeight: VLCStyle.iconWrapper_height

    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    color: theme.palette.fgA2
    font.pixelSize: VLCStyle.fontSize_body

    text: (paintOnly || !value) ? placeholder : value

    property string value: ""
}
