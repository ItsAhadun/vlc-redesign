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
import VLC.Player
import VLC.Util

// Seek bar hover card, "thumbnail" component (design/SPEC.md 3.11):
// 272x189 card, 252x142 frame of the video at (10, 10) and the time below.
// Without video (or without thumbnailer) only the time is shown.
T.Control {
    id: root

    // position (0..1) under the pointer
    property real position: 0
    property bool thumbnailEnabled: true
    property string chapterName: ""

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    readonly property bool _showThumbnail: thumbnailEnabled && seekPreview.available

    padding: VLCStyle.space_10
    topPadding: _showThumbnail ? VLCStyle.space_10 : VLCStyle.space_6
    bottomPadding: _showThumbnail ? VLCStyle.space_8 : VLCStyle.space_6

    implicitWidth: _showThumbnail ? VLCStyle.seekPreview_width
                                  : implicitContentWidth + leftPadding + rightPadding
    implicitHeight: _showThumbnail ? VLCStyle.seekPreview_height
                                   : implicitContentHeight + topPadding + bottomPadding

    SeekPreview {
        id: seekPreview

        player: Player
        ctx: MainCtx

        thumbnailWidth: Math.round((VLCStyle.seekPreview_width - VLCStyle.space_20)
                                   * MainCtx.effectiveDevicePixelRatio(root.Window.window))
    }

    // throttle the thumbnail requests while the pointer moves
    Timer {
        id: requestTimer
        interval: 60
        onTriggered: {
            if (root._showThumbnail)
                seekPreview.request(root.position)
        }
    }

    onPositionChanged: {
        if (!requestTimer.running)
            requestTimer.start()
    }

    Component.onCompleted: {
        if (root._showThumbnail)
            seekPreview.request(root.position)
    }

    background: Rectangle {
        radius: VLCStyle.radius_large
        color: theme.palette.bgA3Transparent

        Widgets.RoundedRectangleShadow {
            blurRadius: VLCStyle.popupShadow_blurRadius
            yOffset: VLCStyle.popupShadow_yOffset
            color: VLCStyle.popupShadow_color
        }
    }

    contentItem: Column {
        spacing: VLCStyle.space_4

        Rectangle {
            visible: root._showThumbnail

            width: VLCStyle.seekPreview_width - VLCStyle.space_20
            height: VLCStyle.dp(142, VLCStyle.scale)

            radius: VLCStyle.radius_small
            color: theme.palette.bgB2
            clip: true

            Image {
                anchors.fill: parent

                source: seekPreview.source
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                smooth: true
            }
        }

        T.Label {
            width: root._showThumbnail ? (VLCStyle.seekPreview_width - VLCStyle.space_20) : implicitWidth

            horizontalAlignment: Text.AlignHCenter

            text: {
                // "00:02:10" like the time labels of the control bar
                const time = Player.length.scale(root.position)
                const total = time.valid() ? Math.max(0, time.toSeconds()) : 0
                const pad = (n) => (n < 10 ? "0" : "") + n
                let t = pad(Math.floor(total / 3600)) + ":" + pad(Math.floor(total / 60) % 60) + ":" + pad(total % 60)
                if (root.chapterName)
                    t += " - " + root.chapterName
                return t
            }

            elide: Text.ElideRight
            color: theme.palette.fgA2
            font.pixelSize: VLCStyle.fontSize_body
        }
    }
}
