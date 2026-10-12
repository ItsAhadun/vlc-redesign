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

// Music player (design/SPEC.md 2.1 "Player - Music" 4767:23726): the album
// art enlarged, blurred and darkened as a full-bleed background, the art
// centered (738x737 in a 1920x986 area, radius 12) and "title - artist"
// (24 px, FG/2) under it. The current lyric line, when the media has lyrics,
// is shown under the caption; with the lyrics view on (MainCtx.lyricsMode,
// "Show lyrics" in the audio popup) the synced lyrics fill the left part.
FocusScope {
    id: root

    property url coverSource

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    // design proportions: 738 / 986 of the height, 74 gap, 29 caption
    readonly property real _artSize: Math.max(0, Math.min(height * 0.748,
                                                          height - _gap - caption.height - VLCStyle.space_24 * 2,
                                                          (lyricsLayout ? width * 0.45 : width) - VLCStyle.space_24 * 2))
    readonly property real _gap: Math.min(VLCStyle.dp(74, VLCStyle.scale), height * 0.075)

    signal wheelEvent(var wheel)

    readonly property bool lyricsLayout: MainCtx.lyricsMode && Player.hasLyrics
                                         && width > VLCStyle.colWidth(6)

    // background: blurred, darkened artwork
    Item {
        id: background

        anchors.fill: parent
        clip: true

        Image {
            id: bgImage

            anchors.fill: parent

            source: root.coverSource
            sourceSize: Qt.size(256, 256)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true

            onStatusChanged: liveTimer.transientTurnOnLive()
        }

        Widgets.DualKawaseBlur {
            id: blur

            anchors.fill: parent

            visible: available
            mode: Widgets.DualKawaseBlur.Mode.SixPass
            radius: 3

            live: true

            source: bgImage

            postprocess: true
            tint: "black"
            tintStrength: theme.palette.isDark ? 0.62 : 0.45
            backgroundColor: theme.palette.bgB1

            Component.onCompleted: {
                widthChanged.connect(liveTimer, liveTimer.transientTurnOnLive)
                heightChanged.connect(liveTimer, liveTimer.transientTurnOnLive)
                liveTimer.transientTurnOnLive()
            }

            Timer {
                id: liveTimer

                repeat: false
                interval: VLCStyle.duration_humanMoment

                function transientTurnOnLive() {
                    blur.live = true
                    liveTimer.restart()
                }

                onTriggered: blur.live = false
            }
        }

        // keep the art readable on bright covers
        Rectangle {
            anchors.fill: parent
            color: theme.palette.isDark ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(0, 0, 0, 0.2)
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            wheel.accepted = true
            root.wheelEvent(wheel)
        }
    }

    Loader {
        id: lyricsLoader

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: VLCStyle.space_24

        width: parent.width * 0.55

        active: root.lyricsLayout

        sourceComponent: LyricsFlickable {
            onPlayerPositionChangeRequested: (time) => {
                Player.setTime(time)
                lyricsSyncToPlayback = true
            }
        }
    }

    Item {
        id: artArea

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: root.lyricsLayout ? lyricsLoader.right : parent.left
    }

    Column {
        anchors.centerIn: artArea

        spacing: root._gap

        Item {
            anchors.horizontalCenter: parent.horizontalCenter

            width: root._artSize
            height: root._artSize

            Widgets.RoundedRectangleShadow {
                anchors.fill: art
                radius: VLCStyle.radius_xlarge
                color: Qt.rgba(0, 0, 0, .35)
                yOffset: VLCStyle.dp(12, VLCStyle.scale)
                blurRadius: VLCStyle.dp(40, VLCStyle.scale)
            }

            Widgets.ImageExt {
                id: art

                anchors.fill: parent

                source: root.coverSource
                sourceSize: Qt.size(Helpers.alignUp(root._artSize * MainCtx.effectiveDevicePixelRatio(root.Window.window), 32),
                                    Helpers.alignUp(root._artSize * MainCtx.effectiveDevicePixelRatio(root.Window.window), 32))
                fillMode: Image.PreserveAspectCrop
                radius: VLCStyle.radius_xlarge
                asynchronous: true
                cache: false

                backgroundColor: theme.palette.bgB2

                Accessible.role: Accessible.Graphic
                Accessible.name: qsTr("Cover")
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: VLCStyle.space_8

            T.Label {
                id: caption

                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, artArea.width - VLCStyle.space_24 * 2)

                text: {
                    const title = Player.title || Player.name
                    return Player.artist ? qsTr("%1 - %2").arg(title).arg(Player.artist) : title
                }

                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                color: theme.palette.fg2
                font.pixelSize: VLCStyle.fontSize_headline

                Accessible.description: qsTr("title and artist")
            }

            T.Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, root.width - VLCStyle.space_24 * 2)

                visible: Player.hasLyrics && text !== "" && !root.lyricsLayout
                text: Player.currentLyric.text

                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                color: theme.palette.fgA2
                font.pixelSize: VLCStyle.fontSize_title

                Accessible.role: Accessible.StaticText
                Accessible.name: qsTr("Lyrics")
            }
        }
    }
}
