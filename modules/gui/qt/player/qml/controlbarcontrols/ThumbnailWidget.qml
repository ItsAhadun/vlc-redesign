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

import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

// "Thumbnail": artwork of the playing media
Item {
    id: root

    property bool paintOnly: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    implicitWidth: VLCStyle.iconWrapper_height
    implicitHeight: VLCStyle.iconWrapper_height

    Rectangle {
        anchors.fill: parent
        radius: VLCStyle.radius_small
        color: theme.palette.bgA4
    }

    Widgets.ImageExt {
        anchors.fill: parent
        visible: !root.paintOnly
        source: (Player.artwork && Player.artwork.toString()) ? VLCAccessImage.uri(Player.artwork)
                                                              : ""
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectCrop
        radius: VLCStyle.radius_small
        asynchronous: true
    }
}
