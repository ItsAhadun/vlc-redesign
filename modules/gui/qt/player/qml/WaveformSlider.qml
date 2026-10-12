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
import VLC.Player

// Music player seek bar, "waveform" variant of the Controls component
// (design/SPEC.md 2.1 Player - Music): decorative bars on the BG/B2 track,
// played bars in Accent/Main, unplayed in grey, an accent handle. Same seek
// interaction as SliderBar (click, drag, wheel, keys, hover card).
SliderBar {
    id: control

    // shape seed: same media, same waveform
    property string seed: {
        const url = Player.url.toString()
        return url !== "" ? url : (Player.title + Player.artist)
    }

    // the waveform has no thumbnail, only the time card
    thumbnailEnabled: false

    readonly property real _inset: VLCStyle.dp(4, VLCStyle.scale)

    background: Item {
        width: control.availableWidth
        implicitHeight: control.implicitHeight
        height: implicitHeight

        Rectangle {
            anchors.fill: parent
            radius: control._radius
            color: control._trackColor
        }

        WaveformBars {
            id: unplayedBars

            anchors.fill: parent
            anchors.leftMargin: control._inset
            anchors.rightMargin: control._inset
            anchors.topMargin: control._inset
            anchors.bottomMargin: control._inset

            seed: control.seed
            color: control.colorContext.palette.fgA4
        }

        // played part: same bars in the accent, clipped at the position
        Item {
            x: unplayedBars.x
            y: unplayedBars.y
            height: unplayedBars.height
            width: Math.max(0, Math.min(unplayedBars.width,
                                        control.visualPosition * parent.width - unplayedBars.x))
            clip: true

            WaveformBars {
                width: unplayedBars.width
                height: unplayedBars.height

                seed: control.seed
                color: control.colorContext.palette.accentMain
            }
        }
    }

    handleDelegate: Rectangle {
        implicitWidth: VLCStyle.dp(4, VLCStyle.scale)
        implicitHeight: control.barHeight - VLCStyle.dp(2, VLCStyle.scale)
        radius: VLCStyle.radius_xxsmall
        color: control.colorContext.palette.accentMain
    }
}
