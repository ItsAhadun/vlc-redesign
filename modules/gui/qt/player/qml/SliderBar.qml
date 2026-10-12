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
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.MainInterface
import VLC.Dialogs

T.ProgressBar {
    id: control

    readonly property real _hoveredScalingFactor: 1.8
    property int barHeight: VLCStyle.dp(5, VLCStyle.scale)
    readonly property real _scaledBarHeight: control.barHeight * _hoveredScalingFactor
    readonly property real _scaledY: (-control.barHeight / 2) * (control._hoveredScalingFactor - 1)

    property bool _isSeekPointsShown: true
    readonly property int _seekPointsDistance: VLCStyle.dp(2, VLCStyle.scale)
    readonly property int _seekPointsRadius: VLCStyle.dp(0.5, VLCStyle.scale)
    readonly property real _scaledSeekPointsRadius: _seekPointsRadius * _hoveredScalingFactor

    property bool _currentChapterHovered: false
    property real _tooltipPosition: (Widgets.PointingToolTipAttached.instance?.pos.x ?? 0.0) / width

    property color backgroundColor: theme.bg.primary
    property real touchHandlerMargin: VLCStyle.touchHandlerMargin

    Keys.onRightPressed: Player.jumpFwd()
    Keys.onLeftPressed: Player.jumpBwd()

    Accessible.onIncreaseAction: Player.jumpFwd()
    Accessible.onDecreaseAction: Player.jumpBwd()

    function showChapterMarks() {
        _isSeekPointsShown = true
        seekpointTimer.restart()
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Slider

        enabled: control.enabled
        focused: control.visualFocus
        hovered: hoverHandler.hovered
    }

    Timer {
        id: seekpointTimer
        running: Player.hasChapters && !hoverHandler.hovered && _isSeekPointsShown
        interval: 3000
        onTriggered: control._isSeekPointsShown = false
    }

    Widgets.PointingToolTipAttached.visible: !control.previewEnabled && (hoverHandler.hovered || control.visualFocus || dragHandler.active)

    Widgets.PointingToolTipAttached.text: {
        if (!Widgets.PointingToolTipAttached.instance?.visible)
            return ""

        let _text

        const length = Player.length
        if (hoverHandler.hovered)
            _text = length.scale(Widgets.PointingToolTipAttached.instance.pos.x / control.width)
        else
            _text = Player.time

        _text = _text.formatHMS(length.isSubSecond() ? VLCTick.SubSecondFormattedAsMS : 0)

        if (Player.hasChapters)
            _text += " - " + Player.chapters.getNameAtPosition(control._tooltipPosition)

        return _text
    }

    Widgets.PointingToolTipAttached.pos: Qt.point(hoverHandler.hovered ? Helpers.clamp(hoverHandler.point.position.x, 0, control.availableWidth)
                                                                       : (control.visualPosition * control.width), 0)

    FSM {
        id: fsm
        signal playerUpdatePosition(real position)
        signal pressControl(real position, bool forcePrecise)
        signal releaseControl(real position, bool forcePrecise)
        signal moveControl(real position, bool forcePrecise)
        signal inputChanged()

        //each signal is associated to a key, when a signal is received,
        //transitions of active state for the given key are evaluated
        signalMap: ({
            "playerUpdatePosition": fsm.playerUpdatePosition,
            "pressControl": fsm.pressControl,
            "releaseControl": fsm.releaseControl,
            "moveControl": fsm.moveControl,
            "inputChanged": fsm.inputChanged
        })

        initialState: fsmReleased

        function _setPositionFromValue(position) {
            control.value = position
        }

        function _seekToPosition(position, threshold, forcePrecise) {
            position = Helpers.clamp(position, 0., 1.)
            control.value = position
            if (!forcePrecise) {
                const chapter = Player.chapters.getClosestChapterFromPos(position, threshold)
                if (chapter !== -1) {
                    Player.chapters.selectChapter(chapter)
                    return
                }
            }
            Player.position = position
        }

        FSMState {
            id: fsmReleased

            transitions: ({
                "playerUpdatePosition": {
                    action: (position) => {
                        control.value = position
                    }
                },
                "pressControl": {
                    action: (position, forcePrecise) => {
                        control.forceActiveFocus()
                        fsm._seekToPosition(position, VLCStyle.dp(4, VLCStyle.scale) / control.width, forcePrecise)
                    },
                    target: fsmHeld
                }
            })
        }

        FSMState  {
            id: fsmHeld

            transitions: ({
                "moveControl": {
                    action: (position, forcePrecise) => {
                        fsm._seekToPosition(position, VLCStyle.dp(2, VLCStyle.scale) / control.width, forcePrecise)
                    }
                },
                "releaseControl": {
                    target: fsmReleased
                },
                "inputChanged": {
                    target: fsmHeldWrongInput
                }
            })
        }

        FSMState  {
            id: fsmHeldWrongInput

            function enter() {
                fsm._setPositionFromValue(Player.position)
            }

            transitions: ({
                "playerUpdatePosition": {
                    action: fsm._setPositionFromValue
                },
                "releaseControl": {
                    target: fsmReleased
                }
            })
        }
    }

    Connections {
        target: Player
        function onPositionChanged() {  fsm.playerUpdatePosition(Player.position) }
        function onInputChanged() {  fsm.inputChanged() }
    }

    Component.onCompleted: value = Player.position

    implicitHeight: control.barHeight
    height: implicitHeight

    padding: 0

    //we use our own HoverHandler
    hoverEnabled: false

    HoverHandler {
        id: hoverHandler

        onHoveredChanged: () => {
            if (hovered) {
                if(Player.hasChapters)
                    control._isSeekPointsShown = true
            } else {
                if(Player.hasChapters)
                    seekpointTimer.restart()
            }
        }
    }

    contentItem: Item {
        implicitHeight: control.implicitHeight
        implicitWidth: control.implicitWidth

        //placing the TapHandler directly in the Control doesn't work with 6.2
        TapHandler {
            acceptedButtons: Qt.LeftButton

            gesturePolicy: TapHandler.WithinBounds

            // Make it easier to tap with touch screen:
            margin: MainCtx.usingTouch ? control.touchHandlerMargin : 0.0

            onPressedChanged: {
                if (pressed) {
                    fsm.pressControl(point.position.x / control.width, point.modifiers === Qt.ShiftModifier)
                } else {
                    // NOTE: Point is still valid at this point.
                    fsm.releaseControl(point.position.x / control.width, point.modifiers === Qt.ShiftModifier)
                }
            }
        }

        DragHandler {
            id: dragHandler
            acceptedButtons: Qt.LeftButton

            // Make it easier to drag with touch screen:
            margin: MainCtx.usingTouch ? control.touchHandlerMargin : 0

            target: null
            dragThreshold: 0
            grabPermissions: PointerHandler.CanTakeOverFromAnything

            property bool filterEvents: false

            function moveControl() {
                fsm.moveControl(dragHandler.centroid.position.x / control.width,
                                dragHandler.centroid.modifiers === Qt.ShiftModifier)
            }

            onActiveChanged: {
                if (active) {
                    filterEvents = false
                    fsm.pressControl(centroid.position.x / control.width, centroid.modifiers === Qt.ShiftModifier)
                } else {
                    fsm.releaseControl( centroid.position.x / control.width, centroid.modifiers === Qt.ShiftModifier)
                }
            }

            onCentroidChanged: {
                // FIXME: Qt 6.5 use xAxis.onActiveValueChanged in the DragHandler
                if (filterEvents) {
                    Qt.callLater(dragHandler.moveControl)
                } else {
                    dragHandler.moveControl()
                    filterEvents = true
                }
            }
        }

        WheelHandler {
            orientation: Qt.Vertical | Qt.Horizontal

            acceptedDevices: PointerDevice.AllDevices

            onWheel: (wheel) => {
                wheelToVLC.qmlWheelEvent(wheel)
                wheel.accepted = true
            }
        }

        WheelToVLCConverter {
            id: wheelToVLC

            function handleVertical(steps: int) {
                if (steps > 0)
                    Player.jumpFwd()
                else
                    Player.jumpBwd()
            }

            function handleHorizontal(steps: int) {
                if (steps > 0)
                    Player.jumpBwd()
                else
                    Player.jumpFwd()
            }

            Component.onCompleted: {
                wheelUpDown.connect(wheelToVLC, wheelToVLC.handleVertical)
                wheelLeftRight.connect(wheelToVLC, wheelToVLC.handleHorizontal)
            }
        }
    }

    // redesign seek bar (design/SPEC.md 1.3 "Seek bar"): track BG/B2, played
    // part BG/Accent Bright, Accent/Main handle (seekHandle_width x bar height)
    readonly property real _radius: Math.min(VLCStyle.radius_small, control.barHeight / 2)
    readonly property color _trackColor: theme.palette.bgB2
    readonly property color _playedColor: theme.palette.bgAccentBright
    readonly property color _handleColor: theme.palette.accentMain
    readonly property real _chapterGap: VLCStyle.dp(2, VLCStyle.scale)

    // whether to show the redesign hover card (time + thumbnail) instead of the tooltip
    property bool previewEnabled: true
    // the card shows a frame of the video when possible
    // "Show thumbnail while scrubbing" (qt-seek-thumbnail)
    property bool thumbnailEnabled: {
        SettingsBackend.revision
        return Player.hasVideoOutput && !!SettingsBackend.value("qt-seek-thumbnail")
    }

    background: Item {
        width: control.availableWidth
        implicitHeight: control.implicitHeight
        height: implicitHeight

        Rectangle {
            id: sliderRect
            visible: !Player.hasChapters
            color: control._trackColor
            anchors.fill: parent
            radius: control._radius
        }

        Repeater {
            id: seekpointsRptr

            anchors.left: parent.left
            anchors.right: parent.right
            height: control.barHeight
            visible: Player.hasChapters

            model: Player.chapters

            Rectangle {
                id: seekpointsRect
                readonly property real startPosition: model.startPosition ??  0.0
                readonly property real endPosition: model.endPosition ?? 1.0

                readonly property bool _hovered: hoverHandler.hovered &&
                                        (hoverHandler.point.position.x > x && hoverHandler.point.position.x < x+width)

                x: sliderRect.width * seekpointsRect.startPosition
                width: Math.max(0, sliderRect.width * seekpointsRect.endPosition - x - control._chapterGap)
                height: control.barHeight
                radius: control._radius
                color: control._trackColor
                clip: true

                on_HoveredChanged: {
                    if (_hovered)
                        control._currentChapterHovered = true
                }

                Rectangle {
                    id: progressRepRect
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: parent.radius

                    width: Helpers.clamp(sliderRect.width * control.visualPosition - parent.x, 0, parent.width)
                    color: control._playedColor

                    // TODO: Do not use `Binding` when minimum Qt is 6.12:
                    Binding {
                        target: progressRepRect
                        property: "mutabilityGroup"
                        when: (progressRepRect.mutabilityGroup !== undefined)
                        value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                                      : Item.StaticMutabilityGroup
                    }
                }
            }
        }

        Rectangle {
            id: progressRect
            width: control.visualPosition * parent.width
            visible: !Player.hasChapters
            color: control._playedColor
            height: control.barHeight
            radius: control._radius

            // We use dynamic mutability group because time interpolation
            // may induce rapid change:
            // TODO: Do not use `Binding` when minimum Qt is 6.12:
            Binding {
                target: progressRect
                property: "mutabilityGroup"
                when: (progressRect.mutabilityGroup !== undefined)
                value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                              : Item.StaticMutabilityGroup
            }
        }

        Rectangle {
            id: bufferRect
            property int bufferAnimWidth: VLCStyle.dp(100, VLCStyle.scale)
            property int bufferAnimPosition: 0
            property int bufferFrames: 1000
            property alias animateLoading: loadingAnim.running
            property bool display: false
            property bool buffering: Player.buffering > 0 && Player.buffering < 1

            height: control.barHeight
            opacity: 0.4
            color: control._handleColor
            radius: control._radius

            // TODO: Do not use `Binding` when minimum Qt is 6.12:
            Binding {
                target: bufferRect
                property: "mutabilityGroup"
                when: bufferRect.mutabilityGroup !== undefined
                value: bufferRect.buffering ? Item.DynamicMutabilityGroup
                                            : Item.StaticMutabilityGroup
            }

            Timer {
                id: bufferingTimer
                interval: VLCStyle.duration_humanMoment
                repeat: false
                running: false
                onTriggered: {
                    bufferRect.display = true
                }
            }

            onBufferingChanged: {
                if(buffering)
                {
                    bufferingTimer.start()
                }
                else
                {
                    bufferingTimer.stop()
                    bufferRect.display = false
                }
            }

            states: [
                State {
                    name: "hidden"
                    when: !control.visible
                    PropertyChanges {
                        target: bufferRect
                        width: bufferAnimWidth
                        visible: false
                        x: 0
                        animateLoading: false
                    }
                },
                State {
                    name: "buffering not started"
                    when: control.visible && Player.buffering === 0
                    PropertyChanges {
                        target: bufferRect
                        width: bufferAnimWidth
                        visible: true
                        x: (bufferAnimPosition / bufferFrames) * (parent.width - bufferAnimWidth)
                        animateLoading: true
                    }
                },
                State {
                    name: "time to start playing known"
                    when: control.visible && bufferRect.display
                    PropertyChanges {
                        target: bufferRect
                        width: Player.buffering * parent.width
                        visible: true
                        x: 0
                        animateLoading: false
                    }
                },
                State {
                    name: "playing from buffer"
                    when: control.visible && !bufferRect.display
                    PropertyChanges {
                        target: bufferRect
                        width: Player.buffering * parent.width
                        visible: false
                        x: 0
                        animateLoading: false
                    }
                }
            ]

            SequentialAnimation on bufferAnimPosition {
                id: loadingAnim
                running: bufferRect.animateLoading
                loops: Animation.Infinite
                PropertyAnimation {
                    from: 0.0
                    to: bufferRect.bufferFrames
                    duration: VLCStyle.durationSliderBouncing
                    easing.type: "OutBounce"
                }
                PauseAnimation {
                    duration: VLCStyle.duration_veryLong
                }
                PropertyAnimation {
                    from: bufferRect.bufferFrames
                    to: 0.0
                    duration: VLCStyle.durationSliderBouncing
                    easing.type: "OutBounce"
                }
                PauseAnimation {
                    duration: VLCStyle.duration_veryLong
                }
            }
        }
    }

    // the handle sits at the end of the played part, full bar height
    property Component handleDelegate: Rectangle {
        implicitWidth: VLCStyle.seekHandle_width
        implicitHeight: control.barHeight
        radius: Math.min(VLCStyle.radius_xsmall, width / 2)
        color: control._handleColor
    }

    // thin bars (miniplayer strip) only show the handle on hover
    property bool alwaysShowHandle: control.barHeight >= VLCStyle.dp(12, VLCStyle.scale)

    Loader {
        id: sliderHandle

        sourceComponent: control.handleDelegate

        x: Helpers.clamp(control.visualPosition * control.availableWidth - width / 2, 0, control.availableWidth - width)
        y: (control.barHeight - height) / 2

        visible: control.enabled && (control.alwaysShowHandle || hoverHandler.hovered || control.visualFocus || dragHandler.active)

        // We use dynamic mutability group because time interpolation
        // may induce rapid change:
        // TODO: Do not use `Binding` when minimum Qt is 6.12:
        Binding {
            target: sliderHandle
            property: "mutabilityGroup"
            when: (sliderHandle.mutabilityGroup !== undefined)
            value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                          : Item.StaticMutabilityGroup
        }
    }

    // Hover card: time (+ video thumbnail), "thumbnail" component 2151:9673
    Loader {
        id: previewLoader

        active: control.previewEnabled && control.enabled
                && (hoverHandler.hovered || dragHandler.active)

        z: 10

        readonly property real pointerX: dragHandler.active ? dragHandler.centroid.position.x
                                                            : (hoverHandler.hovered ? hoverHandler.point.position.x : 0)
        readonly property real pointerPosition: Helpers.clamp(pointerX / Math.max(1, control.width), 0, 1)

        x: Helpers.clamp(pointerX - width / 2, 0, Math.max(0, control.width - width))
        y: -height - VLCStyle.space_8

        sourceComponent: SeekPreviewCard {
            position: previewLoader.pointerPosition
            thumbnailEnabled: control.thumbnailEnabled
            chapterName: Player.hasChapters ? Player.chapters.getNameAtPosition(previewLoader.pointerPosition) : ""
        }
    }
}

