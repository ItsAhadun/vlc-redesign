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
import VLC.Player
import VLC.Dialogs
import VLC.Widgets as Widgets

// "subtitles" Controls variant: subtitle track picker, add a file and delay.
PlayerPopup {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    contentItem: PopupList {
        id: list

        PopupSection {
            width: list.width
            separator: false
            text: qsTr("Subtitle Track")
        }

        Repeater {
            model: Player.subtitleTracks

            delegate: PopupOption {
                required property var model

                width: list.width
                text: model.display
                checked: model.checked
                onClicked: model.checked = !model.checked
            }
        }

        PopupOption {
            width: list.width
            iconText: VLCIcons.add
            text: qsTr("Add Subtitle File…")
            onClicked: {
                root.close()
                DialogsProvider.loadSubtitlesFile()
            }
        }

        PopupSection {
            width: list.width
            text: qsTr("Subtitle Delay")
        }

        // delay: - value +
        Item {
            width: list.width
            height: VLCStyle.menuRow_height

            Widgets.IconToolButton {
                id: minusButton
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.space_10
                anchors.verticalCenter: parent.verticalCenter
                text: VLCIcons.remove
                description: qsTr("Decrease the subtitle delay")
                colorContext.palette: VLCStyle.palette
                onClicked: Player.subtitleDelayMS -= 50
            }

            T.Label {
                anchors.centerIn: parent
                text: qsTr("%1 ms").arg(Player.subtitleDelayMS)
                color: theme.palette.fgA2
                font.pixelSize: VLCStyle.fontSize_body
            }

            Widgets.IconToolButton {
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.space_10
                anchors.verticalCenter: parent.verticalCenter
                text: VLCIcons.add
                description: qsTr("Increase the subtitle delay")
                colorContext.palette: VLCStyle.palette
                onClicked: Player.subtitleDelayMS += 50
            }
        }
    }
}
