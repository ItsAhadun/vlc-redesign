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
import VLC.Style
import VLC.Player
import VLC.Dialogs

// "playback" Controls variant: speed ("Values"), video track, aspect ratio
// and zoom ("Dropdown"-like expandable lists) and jump to time.
PlayerPopup {
    id: root

    readonly property var _speeds: [
        { text: "0.5x", value: 0.5 },
        { text: "0.75x", value: 0.75 },
        { text: "1x", value: 1.0 },
        { text: "1.25x", value: 1.25 },
        { text: "1.5x", value: 1.5 },
        { text: "2x", value: 2.0 }
    ]

    property string _expanded: ""

    onClosed: _expanded = ""

    contentItem: PopupList {
        id: list

        PopupSection {
            width: list.width
            separator: false
            text: qsTr("Playback Speed")
        }

        Item {
            width: list.width
            height: speed.height + VLCStyle.space_8

            SegmentedValues {
                id: speed

                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - VLCStyle.space_14 * 2

                enabled: Player.ratechangable
                values: root._speeds
                currentIndex: root._speeds.findIndex((v) => Math.abs(v.value - Player.rate) < 0.01)

                onActivated: (index, value) => Player.rate = value
            }
        }

        PopupOption {
            width: list.width
            visible: Player.videoTracks.count > 1
            text: qsTr("Video Track")
            showChevron: root._expanded !== "video"
            onClicked: root._expanded = (root._expanded === "video") ? "" : "video"
        }

        Repeater {
            model: root._expanded === "video" ? Player.videoTracks : null

            delegate: PopupOption {
                required property var model
                width: list.width
                leftPadding: VLCStyle.space_20
                text: model.display
                checked: model.checked
                onClicked: model.checked = !model.checked
            }
        }

        PopupOption {
            width: list.width
            visible: Player.hasVideoOutput
            text: qsTr("Aspect Ratio")
            iconText: VLCIcons.aspect_ratio
            showChevron: root._expanded !== "aspect"
            onClicked: root._expanded = (root._expanded === "aspect") ? "" : "aspect"
        }

        Repeater {
            model: root._expanded === "aspect" ? Player.aspectRatio : null

            delegate: PopupOption {
                required property var model
                required property int index
                width: list.width
                leftPadding: VLCStyle.space_20
                text: model.display
                checked: model.checked
                onClicked: Player.aspectRatio.toggleIndex(index)
            }
        }

        PopupOption {
            width: list.width
            visible: Player.hasVideoOutput
            text: qsTr("Zoom")
            iconText: VLCIcons.search
            showChevron: root._expanded !== "zoom"
            onClicked: root._expanded = (root._expanded === "zoom") ? "" : "zoom"
        }

        Repeater {
            model: root._expanded === "zoom" ? Player.zoom : null

            delegate: PopupOption {
                required property var model
                required property int index
                width: list.width
                leftPadding: VLCStyle.space_20
                text: model.display
                checked: model.checked
                onClicked: Player.zoom.toggleIndex(index)
            }
        }

        PopupSection {
            width: list.width
            text: qsTr("More")
        }

        PopupOption {
            width: list.width
            iconText: VLCIcons.time
            text: qsTr("Jump to Time")
            rightText: "Ctrl + T"
            onClicked: {
                root.close()
                DialogsProvider.gotoTimeDialog()
            }
        }

        PopupOption {
            width: list.width
            iconText: VLCIcons.effect_filter
            text: qsTr("Video Effects")
            showChevron: true
            onClicked: {
                root.close()
                DialogsProvider.extendedDialog()
            }
        }
    }
}
