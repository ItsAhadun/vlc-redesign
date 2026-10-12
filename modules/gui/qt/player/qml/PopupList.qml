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
import VLC.Widgets as Widgets

// Scrollable column of popup content (sections and options) for PlayerPopup.
Flickable {
    id: root

    default property alias content: column.data

    // fixed width, the rows fill it ("Menu option" rows are 257-284 wide)
    implicitWidth: VLCStyle.dp(292, VLCStyle.scale)
    implicitHeight: column.implicitHeight

    contentWidth: width
    contentHeight: column.implicitHeight

    clip: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds

    T.ScrollBar.vertical: Widgets.ScrollBarExt { }

    Column {
        id: column

        width: root.width
    }
}
