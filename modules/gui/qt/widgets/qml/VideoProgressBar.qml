/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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

//we want the progress bar to match the radius of the of the video thumbnail
//so we generarte two rectangles with the right radius and we clip the part we
//want to hide
Item {
    id: progressBar

    // Redesign: Accent/Main watched progress along the thumbnail bottom (design/SPEC.md 1.3)
    implicitHeight: VLCStyle.watchedProgress_height

    clip :true

    property real value: 0
    property int radius: implicitHeight

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Slider
    }

    // the played part, the rounded rectangle below spans the whole bar so
    // that the bottom corners follow the thumbnail rounding
    Item {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        width: parent.width * Math.max(0, Math.min(1, progressBar.value))
        clip: true

        Rectangle {
            id: rectangle

            anchors.left: parent.left
            anchors.bottom: parent.bottom

            width: progressBar.width
            height: Math.max(progressBar.radius * 2, //to have at least the proper radius applied
                             progressBar.height + radius) //the top radius section should be always clipped

            radius: progressBar.radius
            color: (theme.palette ?? VLCStyle.palette).accentMain
        }
    }
}
