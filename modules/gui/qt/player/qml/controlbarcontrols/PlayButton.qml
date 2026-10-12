/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Playlist
import VLC.Util

// Redesign "play" component (design/SPEC.md 3.4): a 54x28 pill, Accent/Main
// with a dark glyph in the "play" state, FG/A3 in the "pause" state.
// Press and hold stops the playback (as before).
T.Control {
    id: root

    // Properties

    property bool paintOnly: false

    readonly property bool _playing: !paintOnly
                                     && Player.playingState !== Player.PLAYING_STATE_PAUSED
                                     && Player.playingState !== Player.PLAYING_STATE_STOPPED

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.ButtonAccent

        enabled: root.enabled || root.paintOnly
        focused: root.visualFocus
        hovered: mouseArea.containsMouse
        pressed: mouseArea.containsPress
    }

    property bool _keyOkPressed: false

    // Aliases

    property alias cursorInside: mouseArea.containsMouse

    // Settings

    implicitWidth: VLCStyle.playButton_width
    implicitHeight: VLCStyle.playButton_height

    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Play/Pause")
    AccessibleCompat.id: "playButton"
    Accessible.checkable: true
    Accessible.checked: root._playing
    Accessible.onPressAction: MainPlaylistController.togglePlayPause()
    Accessible.onToggleAction: MainPlaylistController.togglePlayPause()

    // Tooltip

    T.ToolTip.visible: (hovered || visualFocus)
    T.ToolTip.delay: VLCStyle.delayToolTipAppear
    T.ToolTip.text: root._playing ? qsTr("Pause") : qsTr("Play")

    // Keys

    Keys.onPressed: (event) => {
        if (KeyHelper.matchOk(event) ) {
            if (!event.isAutoRepeat) {
                _keyOkPressed = true
                keyHoldTimer.restart()
            }
            event.accepted = true
        }
        Navigation.defaultKeyAction(event)
    }

    Keys.onReleased: (event) => {
        if (KeyHelper.matchOk(event)) {
            if (!event.isAutoRepeat) {
                _keyOkPressed = false
                keyHoldTimer.stop()
                if (Player.playingState !== Player.PLAYING_STATE_STOPPED)
                    MainPlaylistController.togglePlayPause()
            }
            event.accepted = true
        }
    }

    // Functions

    function _pressAndHoldAction() {
        _keyOkPressed = false
        MainPlaylistController.stop()
    }

    // Children

    Timer {
        id: keyHoldTimer

        interval: mouseArea.pressAndHoldInterval
        repeat: false

        onTriggered: root._pressAndHoldAction()
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent

        hoverEnabled: true
        enabled: !root.paintOnly

        onPressed: root.forceActiveFocus(Qt.MouseFocusReason)

        onClicked: (mouse) => {
            MainPlaylistController.togglePlayPause()
            mouse.accepted = true
        }

        onPressAndHold: (mouse) => {
            root._pressAndHoldAction()
            mouse.accepted = true
        }
    }

    contentItem: Widgets.IconLabel {
        text: root._playing ? VLCIcons.pause_filled : VLCIcons.play_filled

        // dark glyph on the accent (FG/B1, or light on dark accents)
        color: root._playing ? theme.palette.fgB1 : theme.palette.fgOnAccent

        font.pixelSize: VLCStyle.icon_normal

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        Accessible.ignored: true
    }

    background: Rectangle {
        radius: VLCStyle.radius_medium

        color: {
            const p = theme.palette
            if (root._playing)
                return (mouseArea.containsMouse || root.visualFocus) ? p.fgA2 : p.fgA3
            if (mouseArea.containsPress || root._keyOkPressed)
                return p.accentDim
            if (mouseArea.containsMouse || root.visualFocus)
                return p.accentBright
            return p.accentMain
        }

        border.width: root.visualFocus ? VLCStyle.focus_border : 0
        border.color: theme.visualFocus

        scale: (root._keyOkPressed || mouseArea.containsPress) ? 0.95 : 1.0

        Behavior on color {
            enabled: theme.initialized
            ColorAnimation {
                duration: VLCStyle.duration_veryShort
                easing.type: Easing.InOutSine
            }
        }
    }
}
