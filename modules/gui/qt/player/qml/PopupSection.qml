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

// Caption of a group of options in a player popup (14 px, FG/A3), with an
// optional Divider/Dim separator above it.
Column {
    id: root

    property alias text: caption.text
    property bool separator: true

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    spacing: 0

    Rectangle {
        visible: root.separator
        width: root.width
        height: visible ? VLCStyle.dp(1, VLCStyle.scale) : 0
        color: theme.palette.dividerDim
    }

    T.Label {
        id: caption

        width: root.width
        leftPadding: VLCStyle.space_14
        rightPadding: VLCStyle.space_14
        topPadding: VLCStyle.space_10
        bottomPadding: VLCStyle.space_6

        color: theme.palette.fgA3
        font.pixelSize: VLCStyle.fontSize_body
        elide: Text.ElideRight
    }
}
