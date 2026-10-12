/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
import QtQuick.Layouts
import QtQuick.Templates as T


import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

// "continue" toast of the redesign (Player - Music 4767:23726, 519x52):
// a floating pill above the control bar with the message and a
// "Continue Watching" button. Esc / timeout dismisses it.
// NOTE: the core does not expose the saved position to the interface, so the
// message does not include the time ("You've watched till 00:45:08 already.").
FocusScope {
    id: resumePanel

    property int maxWidth: VLCStyle.dp(519, VLCStyle.scale)

    implicitHeight: VLCStyle.dp(52, VLCStyle.scale)
    implicitWidth: Math.min(maxWidth, row.implicitWidth + VLCStyle.space_10 * 2)

    visible: false
    enabled: visible

    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("Resume dialog")

    signal hidden()

    function showResumePanel ()
    {
        resumePanel.visible = true
        continueBtn.forceActiveFocus()
        resumeTimeout.start()
    }

    function hideResumePanel() {
        resumeTimeout.stop()
        resumePanel.visible = false
        Player.acknowledgeRestoreCallback()
        hidden()
    }

    Timer {
        id: resumeTimeout
        interval: 10000
        onTriggered: {
            resumePanel.visible = false
            hidden()
        }
    }

    Connections {
        target: Player
        function onCanRestorePlaybackChanged() {
            if (Player.canRestorePlayback) {
                showResumePanel()
            } else {
                hideResumePanel()
            }
        }
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    Component.onCompleted: {
        if (Player.canRestorePlayback) {
            showResumePanel()
        }
    }

    Navigation.cancelAction: function() {
        hideResumePanel()
    }

    Rectangle {
        anchors.fill: parent
        radius: VLCStyle.radius_large
        color: theme.palette.bgA3Transparent

        Widgets.RoundedRectangleShadow {
            blurRadius: VLCStyle.popupShadow_blurRadius
            yOffset: VLCStyle.popupShadow_yOffset
            color: VLCStyle.popupShadow_color
        }
    }

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.leftMargin: VLCStyle.space_20
        anchors.rightMargin: VLCStyle.space_10

        spacing: VLCStyle.space_16

        T.Label {
            id: label

            Layout.fillWidth: true

            color: theme.palette.fgA2
            font.pixelSize: VLCStyle.fontSize_body
            elide: Text.ElideRight

            text: Player.hasVideoOutput ? qsTr("You’ve watched this already.")
                                        : qsTr("You’ve listened to this already.")
        }

        T.Button {
            id: continueBtn

            Layout.preferredWidth: Math.max(VLCStyle.dp(146, VLCStyle.scale), implicitContentWidth + leftPadding + rightPadding)
            Layout.preferredHeight: VLCStyle.dialogButton_height

            text: Player.hasVideoOutput ? qsTr("Continue Watching") : qsTr("Continue Listening")

            AccessibleCompat.id: "resumeContinueButton"

            focus: true

            horizontalPadding: VLCStyle.space_14

            background: Rectangle {
                radius: VLCStyle.radius_small
                color: continueBtn.hovered ? theme.palette.bgA2 : theme.palette.bgA4
                border.width: continueBtn.visualFocus ? VLCStyle.focus_border : 0
                border.color: theme.visualFocus
            }

            contentItem: T.Label {
                text: continueBtn.text
                color: theme.palette.fgA2
                font.pixelSize: VLCStyle.fontSize_body
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                Player.restorePlaybackPos()
                hideResumePanel()
            }

            Navigation.parentItem: resumePanel
            Keys.priority: Keys.AfterItem
            Keys.onPressed: (event) =>  continueBtn.Navigation.defaultKeyAction(event)
        }
    }
}
