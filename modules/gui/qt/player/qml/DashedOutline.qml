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
import QtQuick.Shapes

import VLC.Style

// Dashed 1px rectangle, used to outline the customizable slots of the player
// in "Customize Player" mode (design/SPEC.md 2.1 Player - customize).
Shape {
    id: root

    property color color: "grey"
    property real dash: 2 // in units of the stroke width

    enabled: false

    ShapePath {
        strokeColor: root.color
        strokeWidth: Math.max(1, VLCStyle.dp(1, VLCStyle.scale))
        strokeStyle: ShapePath.DashLine
        dashPattern: [root.dash, root.dash]
        fillColor: "transparent"
        capStyle: ShapePath.FlatCap

        readonly property real o: strokeWidth / 2

        startX: o; startY: o
        PathLine { x: root.width - 0.5; y: 0.5 }
        PathLine { x: root.width - 0.5; y: root.height - 0.5 }
        PathLine { x: 0.5; y: root.height - 0.5 }
        PathLine { x: 0.5; y: 0.5 }
    }
}
