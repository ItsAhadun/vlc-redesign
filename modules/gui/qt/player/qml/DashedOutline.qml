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

import VLC.Style

// Dashed 1px rectangle, used to outline the customizable slots of the player
// in "Customize Player" mode (design/SPEC.md 2.1 Player - customize).
//
// NOTE: drawn with a Canvas, not QtQuick.Shapes: the Windows (static contrib)
// Qt only links the QML modules that upstream VLC imports, QtQuick.Shapes is
// not one of them ("module QtQuick.Shapes is not installed" makes every QML
// file using this type fail to load). design/tools/qml-check.sh enforces the
// import allowlist (design/tools/qml-imports-allowlist.txt).
Canvas {
    id: root

    property color color: "grey"
    property real dash: 2 // in units of the stroke width

    readonly property real strokeWidth: Math.max(1, VLCStyle.dp(1, VLCStyle.scale))

    enabled: false

    onColorChanged: requestPaint()
    onDashChanged: requestPaint()
    onStrokeWidthChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (width <= 0 || height <= 0)
            return

        const sw = root.strokeWidth
        const o = sw / 2
        ctx.lineWidth = sw
        ctx.lineCap = "butt"
        ctx.strokeStyle = root.color
        // dash lengths are in units of the line width, like ShapePath.dashPattern
        ctx.setLineDash([root.dash, root.dash])
        ctx.strokeRect(o, o, width - sw, height - sw)
    }
}
