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

// "audio" Controls variant: audio track picker, visualizer and effects.
PlayerPopup {
    id: root

    contentItem: PopupList {
        id: list

        PopupSection {
            width: list.width
            separator: false
            text: qsTr("Audio Track")
        }

        Repeater {
            model: Player.audioTracks

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
            text: qsTr("Add Audio Track File…")
            onClicked: {
                root.close()
                DialogsProvider.loadAudioFile()
            }
        }

        PopupSection {
            width: list.width
            visible: visualizerRepeater.count > 0
            text: qsTr("Visualizer")
        }

        Repeater {
            id: visualizerRepeater

            model: Player.audioVisualization

            delegate: PopupOption {
                required property var model
                required property int index

                width: list.width
                text: model.display
                checked: model.checked
                onClicked: Player.audioVisualization.toggleIndex(index)
            }
        }

        PopupOption {
            width: list.width
            visible: Player.hasLyrics
            iconText: VLCIcons.topbar_music
            text: qsTr("Show Lyrics")
            checked: MainCtx.lyricsMode
            onClicked: MainCtx.lyricsMode = !MainCtx.lyricsMode
        }

        PopupSection {
            width: list.width
            text: qsTr("Effects")
        }

        PopupOption {
            width: list.width
            iconText: VLCIcons.effect_filter
            text: qsTr("Equalizer and Effects")
            showChevron: true
            onClicked: {
                root.close()
                DialogsProvider.extendedDialog()
            }
        }

        PopupOption {
            width: list.width
            iconText: VLCIcons.time
            text: qsTr("Synchronization")
            showChevron: true
            onClicked: {
                root.close()
                DialogsProvider.synchroDialog()
            }
        }
    }
}
