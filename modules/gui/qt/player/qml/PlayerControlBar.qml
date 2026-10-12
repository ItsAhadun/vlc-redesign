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
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls
import VLC.Util
import VLC.Dialogs

// Redesign player control bar (design/SPEC.md 2.1, "Controls" 491:1780):
// one 54 px row on BG/A3, left to right:
//   [left controls] current time [seek bar] duration [right controls]
// The left/center/right controls come from the control bar profile
// (PlayerControlbarModel), so the "Customize Player" editor drives them.
// `musicMode` swaps the seek bar for the decorative waveform.
T.Pane {
    id: root

    // Properties

    property int identifier: -1

    property bool musicMode: false

    // in-place "Customize Player" mode: the live controls are replaced by the
    // editable rows (see PlayerCustomizeRow.qml)
    property bool customizeMode: false
    property Item customizeDragLayer: null

    // y of the top of the bar in root coordinates (popups open above it)
    readonly property real sliderY: 0

    readonly property alias trackPositionSlider: seekLoader.item

    property var menu: undefined

    readonly property PlayerControlbarModel model: {
        if (!!MainCtx.controlbarProfileModel.currentModel)
            return MainCtx.controlbarProfileModel.currentModel.getModel(identifier)
        else
            return null
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    // Signals

    signal requestLockUnlockAutoHide(bool lock)

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: VLCStyle.controlBar_height

    leftPadding: VLCStyle.space_20
    rightPadding: VLCStyle.space_20
    topPadding: 0
    bottomPadding: 0

    enabled: visible

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => root.Navigation.defaultKeyAction(event)

    Accessible.name: qsTr("Player controls")
    AccessibleCompat.id: "playerControlBar"

    // Functions

    // "00:02:10": the design always shows hours, minutes and seconds
    function formatTime(t) : string {
        if (!t || !t.valid())
            return "--:--:--"
        const total = Math.max(0, t.toSeconds())
        const pad = (n) => (n < 10 ? "0" : "") + n
        return pad(Math.floor(total / 3600)) + ":" + pad(Math.floor(total / 60) % 60) + ":" + pad(total % 60)
    }

    function showChapterMarks() {
        trackPositionSlider?.showChapterMarks?.()
    }

    function applyMenu(menu) {
        if (root.menu === menu)
            return

        // NOTE: When applying a new menu we hide the previous one.
        if (menu)
            dismiss()

        root.menu = menu
    }

    function dismiss() {
        if ((typeof menu === undefined) || !menu)
            return
        if (menu.hasOwnProperty("dismiss"))
            menu.dismiss()
        else if (menu.hasOwnProperty("close"))
            menu.close()
    }

    // Children

    component TimeLabel : T.Label {
        id: timeLabel

        property bool clickable: false
        signal clicked()

        Layout.preferredWidth: VLCStyle.timeLabel_width
        Layout.preferredHeight: VLCStyle.seekBar_height

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight

        color: theme.palette.fgA2
        font.pixelSize: VLCStyle.fontSize_body
        font.features: { "tnum": 1 } // tabular digits, the label does not jitter

        background: Rectangle {
            radius: VLCStyle.radius_small
            color: (timeLabel.clickable && timeHover.hovered) ? theme.palette.hoverOverlay : "transparent"
        }

        HoverHandler {
            id: timeHover
            enabled: timeLabel.clickable
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: timeLabel.clickable
            onTapped: timeLabel.clicked()
        }

        // TODO: Do not use `Binding` when minimum Qt is 6.12:
        Binding {
            target: timeLabel
            property: "mutabilityGroup"
            when: (timeLabel.mutabilityGroup !== undefined)
            value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.ModerateMutabilityGroup
                                                                          : Item.StaticMutabilityGroup
        }
    }

    background: Rectangle {
        color: theme.palette.bgA3
    }

    contentItem: RowLayout {
        id: row

        spacing: VLCStyle.space_20

        focus: true

        ControlLayout {
            id: leftLayout

            Layout.preferredWidth: implicitWidth
            Layout.fillHeight: true

            visible: !root.customizeMode && !!root.model && root.model.left.count > 0

            model: ControlListFilter {
                sourceModel: root.model?.left ?? null

                player: Player
                ctx: MainCtx
            }

            alignment: Qt.AlignVCenter
            spacing: VLCStyle.space_6
            iconWrapper: true

            focus: true

            altFocusAction: () => Navigation.defaultNavigationRight()

            Navigation.parentItem: root
            Navigation.rightItem: centerLayout.visible ? centerLayout : seekLoader

            onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
            onMenuOpened: (menu) => root.applyMenu(menu)

            Component.onCompleted: root.forceUnlock.connect(leftLayout.forceUnlock)
        }

        ControlLayout {
            id: centerLayout

            Layout.preferredWidth: implicitWidth
            Layout.fillHeight: true

            visible: !root.customizeMode && !!root.model && root.model.center.count > 0

            model: ControlListFilter {
                sourceModel: root.model?.center ?? null

                player: Player
                ctx: MainCtx
            }

            alignment: Qt.AlignVCenter
            spacing: VLCStyle.space_6
            iconWrapper: true

            altFocusAction: () => Navigation.defaultNavigationRight()

            Navigation.parentItem: root
            Navigation.leftItem: leftLayout
            Navigation.rightItem: seekLoader

            onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
            onMenuOpened: (menu) => root.applyMenu(menu)

            Component.onCompleted: root.forceUnlock.connect(centerLayout.forceUnlock)
        }

        // editable rows of the "Customize Player" mode
        Loader {
            id: customizeLeft
            active: root.customizeMode
            visible: active
            Layout.fillHeight: true
            Layout.preferredWidth: item ? item.implicitWidth : 0
            sourceComponent: PlayerCustomizeRow {
                listModel: root.model?.left ?? null
                dragLayer: root.customizeDragLayer
                spacing: VLCStyle.space_6
            }
        }

        Loader {
            id: customizeCenter
            active: root.customizeMode && !!root.model && root.model.center.count > 0
            visible: active
            Layout.fillHeight: true
            Layout.preferredWidth: item ? item.implicitWidth : 0
            sourceComponent: PlayerCustomizeRow {
                listModel: root.model?.center ?? null
                dragLayer: root.customizeDragLayer
                spacing: VLCStyle.space_6
            }
        }

        // time + seek bar + duration (a single slot in the design)
        Item {
            id: seekSlot

            Layout.fillWidth: true
            Layout.fillHeight: true

            implicitWidth: seekGroup.implicitWidth
            implicitHeight: seekGroup.implicitHeight

            DashedOutline {
                anchors.fill: parent
                anchors.topMargin: VLCStyle.space_6
                anchors.bottomMargin: VLCStyle.space_6
                anchors.leftMargin: -VLCStyle.space_4
                anchors.rightMargin: -VLCStyle.space_4
                visible: root.customizeMode
                color: theme.palette.fgA3
            }

        RowLayout {
            id: seekGroup

            anchors.fill: parent

            spacing: VLCStyle.space_10

            TimeLabel {
                id: mediaTime

                text: root.formatTime(Player.time)
            }

            Loader {
                id: seekLoader

                Layout.fillWidth: true
                Layout.preferredHeight: VLCStyle.seekBar_height
                Layout.alignment: Qt.AlignVCenter

                focus: true
                enabled: !root.customizeMode

                sourceComponent: root.musicMode ? waveformComponent : sliderComponent

                Navigation.parentItem: root
                Navigation.leftItem: centerLayout.visible ? centerLayout : leftLayout
                Navigation.rightItem: rightLayout

                Component {
                    id: sliderComponent

                    SliderBar {
                        barHeight: VLCStyle.seekBar_height

                        Accessible.role: Accessible.Slider
                        Accessible.name: qsTr("Progress")
                        AccessibleCompat.id: "progressSlider"

                        enabled: Player.playingState === Player.PLAYING_STATE_PLAYING || Player.playingState === Player.PLAYING_STATE_PAUSED

                        activeFocusOnTab: true
                        focus: true

                        Navigation.parentItem: seekLoader
                        Keys.onPressed: (event) => Navigation.defaultKeyAction(event)
                    }
                }

                Component {
                    id: waveformComponent

                    WaveformSlider {
                        barHeight: VLCStyle.seekBar_height

                        Accessible.role: Accessible.Slider
                        Accessible.name: qsTr("Progress")
                        AccessibleCompat.id: "progressSlider"

                        enabled: Player.playingState === Player.PLAYING_STATE_PLAYING || Player.playingState === Player.PLAYING_STATE_PAUSED

                        activeFocusOnTab: true
                        focus: true

                        Navigation.parentItem: seekLoader
                        Keys.onPressed: (event) => Navigation.defaultKeyAction(event)
                    }
                }
            }

            TimeLabel {
                id: mediaRemainingTime

                readonly property bool showRemainingTime: (MainCtx.showRemainingTime && Player.remainingTime.valid())

                clickable: true
                onClicked: MainCtx.showRemainingTime = !MainCtx.showRemainingTime

                text: showRemainingTime
                      ? "-" + root.formatTime(Player.remainingTime)
                      : root.formatTime(Player.length)

                T.ToolTip.visible: timeTooltipHover.hovered && MainCtx.showRemainingTime && Player.rate !== 1
                T.ToolTip.delay: VLCStyle.delayToolTipAppear
                T.ToolTip.text: {
                    const playbackSpeed = Math.abs(Player.rate)
                    const adjusted = Player.remainingTime.scale(1 / playbackSpeed)
                    return qsTr("%1 (%2x)").arg((adjusted ? adjusted : Player.remainingTime).formatHMS())
                                           .arg(+Player.rate.toFixed(2))
                }

                HoverHandler { id: timeTooltipHover }
            }

        }
        }

        Loader {
            id: customizeRight
            active: root.customizeMode
            visible: active
            Layout.fillHeight: true
            Layout.preferredWidth: item ? item.implicitWidth : 0
            sourceComponent: PlayerCustomizeRow {
                listModel: root.model?.right ?? null
                dragLayer: root.customizeDragLayer
                spacing: VLCStyle.space_12
            }
        }

        ControlLayout {
            id: rightLayout

            Layout.preferredWidth: implicitWidth
            Layout.fillHeight: true

            visible: !root.customizeMode && !!root.model && root.model.right.count > 0

            model: ControlListFilter {
                sourceModel: root.model?.right ?? null

                player: Player
                ctx: MainCtx
            }

            alignment: Qt.AlignVCenter
            spacing: VLCStyle.space_12
            iconWrapper: true

            altFocusAction: () => Navigation.defaultNavigationLeft()

            Navigation.parentItem: root
            Navigation.leftItem: seekLoader

            onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
            onMenuOpened: (menu) => root.applyMenu(menu)

            Component.onCompleted: root.forceUnlock.connect(rightLayout.forceUnlock)
        }
    }
}
