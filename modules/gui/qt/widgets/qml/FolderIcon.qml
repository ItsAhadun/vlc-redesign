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
import VLC.Util

// Folder glyph (no folder glyph in the icon font yet), recolored at runtime.
// TODO(icons): use the redesign "folder" icon once the icon font is regenerated.
Item {
    id: root

    property color color: VLCStyle.palette.fgA2

    // size of the glyph, the item can be bigger (the glyph stays centered)
    property real glyphSize: VLCStyle.icon_normal

    implicitWidth: glyphSize
    implicitHeight: glyphSize

    Image {
        anchors.centerIn: parent

        width: root.glyphSize
        height: root.glyphSize

        sourceSize: Qt.size(root.glyphSize, root.glyphSize)
        fillMode: Image.PreserveAspectFit
        smooth: true

        source: SVGColorImage.colorize("qrc:///misc/folder_glyph.svg")
                    .color1(root.color)
                    .uri()
    }
}
