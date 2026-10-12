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

// "Divider": 1 px vertical separator between controls
Item {
    id: root

    property bool paintOnly: false

    enabled: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    implicitWidth: VLCStyle.space_8
    implicitHeight: VLCStyle.icon_normal

    Rectangle {
        anchors.centerIn: parent
        width: VLCStyle.dp(1, VLCStyle.scale)
        height: VLCStyle.icon_normal
        color: theme.palette.dividerBright
    }
}
