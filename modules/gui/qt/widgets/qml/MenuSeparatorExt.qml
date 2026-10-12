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

// 1 px Divider/Dim separator spanning the menu width (design/SPEC.md 3.9)
T.MenuSeparator {
    id: control

    // the menu palette (set by the menu owner for the dark player)
    property var menuPalette: VLCStyle.palette

    padding: 0
    topPadding: VLCStyle.space_4
    bottomPadding: VLCStyle.space_4

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    contentItem: Item {
        implicitWidth: VLCStyle.dp(257, VLCStyle.scale)
        implicitHeight: VLCStyle.border

        // spans the whole menu, including its padding
        Rectangle {
            x: -VLCStyle.space_4
            width: parent.width + VLCStyle.space_4 * 2
            height: parent.height
            color: control.menuPalette.dividerDim
        }
    }
}
