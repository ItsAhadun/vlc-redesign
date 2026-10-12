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

import VLC.Widgets as Widgets
import VLC.Player
import VLC.Style
import VLC.Util

// Relative jump by `seconds` (backward-/forward-10/15-sec in the design).
// The icon font has 10 s glyphs (skip_back / skip_for); other amounts are
// drawn: a circular arrow with the number below it, like the design.
// TODO(icons): use the backward-15-sec / forward-15-sec icons of the
// redesign set once the icon font is regenerated.
Widgets.IconToolButton {
    id: root

    property int seconds: 10
    property bool forward: true

    readonly property bool _hasGlyph: seconds === 10

    text: _hasGlyph ? (forward ? VLCIcons.skip_for : VLCIcons.skip_back) : " "
    description: forward ? qsTr("Forward %1 seconds").arg(seconds)
                         : qsTr("Backward %1 seconds").arg(seconds)

    enabled: !paintOnly && Player.seekable

    onClicked: Player.jumpSeconds(forward ? seconds : -seconds)

    Canvas {
        id: icon

        visible: !root._hasGlyph

        anchors.centerIn: parent
        width: VLCStyle.icon_normal
        height: VLCStyle.icon_normal

        readonly property color color: root.color
        onColorChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const s = width / 24
            ctx.strokeStyle = color
            ctx.fillStyle = color
            ctx.lineWidth = 1.5 * s
            ctx.lineCap = "round"

            // arc, open at the top, arrow head on the leading side
            const cx = 12 * s, cy = 9.5 * s, r = 6 * s
            ctx.beginPath()
            if (root.forward)
                ctx.arc(cx, cy, r, Math.PI * 1.45, Math.PI * 0.95, true)
            else
                ctx.arc(cx, cy, r, Math.PI * 1.55, Math.PI * 0.05, false)
            ctx.stroke()

            // arrow head
            const tipX = root.forward ? cx + r * 0.55 : cx - r * 0.55
            const tipY = cy - r * 0.95
            const dir = root.forward ? 1 : -1
            ctx.beginPath()
            ctx.moveTo(tipX + dir * 2.8 * s, tipY + 0.2 * s)
            ctx.lineTo(tipX - dir * 0.6 * s, tipY - 2.4 * s)
            ctx.lineTo(tipX - dir * 0.6 * s, tipY + 2.6 * s)
            ctx.closePath()
            ctx.fill()
        }

        T.Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -VLCStyle.dp(1, VLCStyle.scale)

            text: root.seconds
            color: root.color
            font.pixelSize: VLCStyle.dp(8, VLCStyle.scale)
            font.weight: Font.DemiBold
        }
    }
}
