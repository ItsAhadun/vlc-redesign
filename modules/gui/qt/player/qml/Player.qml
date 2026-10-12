/*****************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
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
import QtQml.Models
import QtQuick.Window
import QtQuick.Shapes
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Playlist
import VLC.Player
import VLC.PlayerControls
import VLC.Dialogs
import VLC.Util

// Player page of the redesign (design/SPEC.md 2.1):
//   title bar (40, LocalTopbar, owned by the main window chrome)
//   [side panel 427] [video area, 8 px frame, rounded] [play queue]
//   control bar (54, PlayerControlBar)
// Music (no video): blurred artwork background, big art, waveform seek bar.
// "Hide UI" (Ctrl+\, MainCtx.playerHideUI) and the auto-hide hide the title
// bar, the control bar and the side panel, the video then fills the window
// inside an 8 px frame. "Customize Player" (MainCtx.playerCustomizeMode)
// edits the control bar in place.
FocusScope {
    id: rootPlayer

    // Properties

    //behave like a Page
    property var pagePrefix: []

    // popups of the control bar open above this
    readonly property int positionSliderY: controlBar.y

    readonly property string coverSource: {
        if (Player.artwork &&
            Player.artwork.toString())
            return Player.artwork
        else if (Player.hasVideoOutput)
            return VLCStyle.noArtVideoCover
        else
            return VLCStyle.noArtAlbumCover
    }

    // video layout (vs. music layout)
    readonly property bool videoLayout: MainCtx.hasEmbededVideo || Player.hasVideoOutput

    readonly property bool musicMode: !videoLayout

    // title bar + control bar (+ side panel) shown
    readonly property bool chromeVisible: MainCtx.playerCustomizeMode
                                          || (!MainCtx.playerHideUI
                                              && (playerToolbarVisibilityFSM.isVisible
                                                  || rootPlayer._controlsUnderVideo
                                                  || !playerToolbarVisibilityFSM.started))

    readonly property bool sidePanelShown: chromeVisible
                                           && MainCtx.playerSidePanelVisible
                                           && MainCtx.mediaLibraryAvailable
                                           && !MainCtx.playerCustomizeMode

    // Private

    property bool _controlsUnderVideo: (MainCtx.pinVideoControls
                                        &&
                                        (MainCtx.intfMainWindow.visibility !== Window.FullScreen))

    property bool _keyPressed: false

    // Settings

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Player")
    AccessibleCompat.id: "playerView"

    // Events

    Component.onCompleted: MainCtx.preferHotkeys = true
    Component.onDestruction: {
        MainCtx.preferHotkeys = false
        MainCtx.playerCustomizeMode = false
        MainCtx.playerChromeVisible = true
    }

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => {
        if (event.accepted)
            return

        _keyPressed = true

        rootPlayer.Navigation.defaultKeyAction(event)

        //unhandled keys are forwarded as hotkeys
        if (!event.accepted || !rootPlayer.chromeVisible)
            MainCtx.sendHotkey(event.key, event.modifiers);
    }

    Keys.onReleased: (event) => {
        if (event.accepted || _keyPressed === false)
            return

        _keyPressed = false

        rootPlayer.Navigation.defaultKeyReleaseAction(event)
    }

    on_ControlsUnderVideoChanged: {
        lockUnlockAutoHide(_controlsUnderVideo)
    }

    // "Hide UI" (right-click menu, Ctrl + \)
    Shortcut {
        sequence: "Ctrl+\\"
        context: Qt.WindowShortcut
        onActivated: MainCtx.playerHideUI = !MainCtx.playerHideUI
    }

    Binding {
        target: MainCtx
        property: "playerChromeVisible"
        value: rootPlayer.chromeVisible
    }

    // Functions

    function lockUnlockAutoHide(lock) {
        if (lock) {
            playerToolbarVisibilityFSM.lock()
        } else {
            playerToolbarVisibilityFSM.unlock()
        }
    }

    function enterCustomizeMode() {
        MainCtx.playerHideUI = false
        MainCtx.playerCustomizeMode = true
    }

    // Private

    function _onNavigationCancel() {
        if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP) {
            MainPlaylistController.stop()
        }

        History.previous()
    }

    // the player chrome follows the theme (the controls are no longer drawn
    // over the video)
    ColorContext {
        id: windowTheme

        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    PlayerToolbarVisibilityFSM {
        id: playerToolbarVisibilityFSM

        onForceUnlock:{
            controlBar.forceUnlock()
        }
    }

    PlayerPlaylistVisibilityFSM {
        id: playlistVisibility

        onIsPlaylistVisibleChanged: lockUnlockAutoHide(isPlaylistVisible)
    }

    Connections {
        target: MainCtx

        //playlist
        function onHasEmbededVideoChanged() {
            playlistVisibility.updateVideoEmbed()
            playerToolbarVisibilityFSM.updateVideoEmbed()
        }
        function onAskShow() {
            playerToolbarVisibilityFSM.askShow()
        }
        function onPlayerSidePanelVisibleChanged() {
            rootPlayer.lockUnlockAutoHide(MainCtx.playerSidePanelVisible)
        }
    }

    Connections {
        target: MainCtx.playqueuePanel

        //playlist
        function onDockedChanged() {
            playlistVisibility.updatePlaylistDocked()
        }
        function onVisibleChanged() {
            playlistVisibility.updatePlaylistVisible()
        }
    }

    // Window chrome / frame around the video (Window bg: BG/A3, light BG/A4)
    Rectangle {
        anchors.fill: parent
        color: windowTheme.bg.primary
    }

    // Geometry of the content (video / music) area
    Item {
        id: contentArea

        readonly property real _frame: (rootPlayer.musicMode && rootPlayer.chromeVisible) ? 0 : VLCStyle.windowPadding

        x: rootPlayer.sidePanelShown ? sidePanel.x + sidePanel.width : _frame
        y: rootPlayer.chromeVisible ? titleBarArea.y + titleBarArea.height : _frame

        width: (playlistpopup.visible ? playlistpopup.x : (rootPlayer.width - _frame)) - x
        height: Math.min(controlBar.y, rootPlayer.height - _frame) - y
    }

    Loader {
        id: playerSpecializationLoader

        objectName: "playerSpecializationLoader"

        x: contentArea.x
        y: contentArea.y
        width: contentArea.width
        height: contentArea.height

        sourceComponent: rootPlayer.videoLayout ? videoComponent : audioComponent

        property int cursorShape

        component TouchDragHandler : DragHandler {
            id: touchDragHandler

            acceptedDevices: PointerDevice.TouchScreen

            minimumPointCount: 1
            maximumPointCount: 1

            target: null

            dragThreshold: VLCStyle.margin_normal

            property vector2d lastActiveTranslation

            // TODO: Use `createComponent()` and load directly from module instead, since
            //       it is pointless to keep the `QQmlComponent` around for this object.
            readonly property Component wheelToVLCConverterComponent: Component { WheelToVLCConverter { } }

            property WheelToVLCConverter wheelToVLCConverter

            // We synthesize wheel event with pixel delta. It is a to-do to handle
            // touch properly with precision adjustment, like on Android:
            onActiveTranslationChanged: {
                if (active) {
                    console.assert(wheelToVLCConverter)

                    const delta = Qt.point(activeTranslation.x - lastActiveTranslation.x,
                                           activeTranslation.y - lastActiveTranslation.y)

                    // WheelToVLCConverter can not handle sole pixel delta now, so we also
                    // use angle delta. This is similar to wheel events on some platforms:
                    wheelToVLCConverter.customWheelEvent(delta,
                                                         delta,
                                                         Qt.NoButton,
                                                         Qt.NoModifier,
                                                         true)

                    lastActiveTranslation = activeTranslation
                }
            }

            onActiveChanged: {
                if (active) {
                    if (!wheelToVLCConverter) {
                        wheelToVLCConverter = wheelToVLCConverterComponent.createObject(touchDragHandler)
                        wheelToVLCConverter.vlcWheelKey.connect(MainCtx, MainCtx.sendVLCHotkey)
                    }
                } else {
                    lastActiveTranslation = Qt.vector2d(0, 0)
                }
            }
        }

        // masks the corners of the video with the frame color
        component CornerMask : Shape {
            id: corner

            property real radius: VLCStyle.radius_large
            property color color: windowTheme.bg.primary
            // 0: top-left, 1: top-right, 2: bottom-right, 3: bottom-left
            property int corner: 0

            width: radius
            height: radius

            rotation: corner * 90
            enabled: false

            ShapePath {
                strokeWidth: -1
                fillColor: corner.color
                startX: 0; startY: 0
                PathLine { x: corner.radius; y: 0 }
                PathArc { x: 0; y: corner.radius; radiusX: corner.radius; radiusY: corner.radius; direction: PathArc.Counterclockwise }
                PathLine { x: 0; y: 0 }
            }
        }

        Component {
            id: videoComponent

            FocusScope {
                // Video

                focus: true

                // the video is not embedded (e.g. --no-embedded-video or a
                // compositor without embedding): the area stays dark
                Rectangle {
                    anchors.fill: parent
                    visible: !MainCtx.hasEmbededVideo
                    color: "black"

                    Column {
                        anchors.centerIn: parent
                        spacing: VLCStyle.space_10

                        Widgets.BannerCone {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: windowTheme.palette.accentLogo
                        }

                        T.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("The video plays in a separate window")
                            color: VLCStyle.darkPalette.fgA3
                            font.pixelSize: VLCStyle.fontSize_body
                        }
                    }
                }

                VideoSurface {
                    id: videoSurface

                    anchors.fill: parent

                    // With regard to `ViewBlockingRectangle`, we
                    // do not need to prevent painting anything
                    // behind because there is already nothing
                    // behind (unlike pip player):
                    renderingEnabled: false

                    videoSurfaceProvider: MainCtx.videoSurfaceProvider

                    visible: MainCtx.hasEmbededVideo

                    focus: true

                    cursorShape: playerSpecializationLoader.cursorShape

                    function onMouseEvent() {
                        //short interval for mouse events
                        if (Player.isInteractive)
                            interactiveAutoHideTimer.restart()
                        else
                            playerToolbarVisibilityFSM.mouseMove();
                    }

                    Component.onCompleted: {
                        mouseMoved.connect(videoSurface.onMouseEvent)
                        mousePressed.connect(videoSurface.onMouseEvent)
                        mouseReleased.connect(videoSurface.onMouseEvent)
                        mouseDblClicked.connect(videoSurface.onMouseEvent)
                    }

                    Binding on cursorShape {
                        when: playerToolbarVisibilityFSM.started
                            && !rootPlayer.chromeVisible
                            && !interactiveAutoHideTimer.running
                        value: Qt.BlankCursor
                    }

                    TouchDragHandler {

                    }
                }

                // rounded video corners (about 8 in the design)
                CornerMask { corner: 0; x: 0; y: 0 }
                CornerMask { corner: 1; x: parent.width - width; y: 0 }
                CornerMask { corner: 2; x: parent.width - width; y: parent.height - height }
                CornerMask { corner: 3; x: 0; y: parent.height - height }
            }
        }

        Component {
            id: audioComponent

            MusicPlayerView {
                focus: true

                coverSource: VLCAccessImage.uri(rootPlayer.coverSource)

                onWheelEvent: (wheel) => wheelToVlc.qmlWheelEvent(wheel)

                TouchDragHandler {
                    wheelToVLCConverter: wheelToVlc
                }

                WheelToVLCConverter {
                    id: wheelToVlc

                    onVlcWheelKey: (key) => MainCtx.sendVLCHotkey(key)
                }

                HoverHandler {
                    onPointChanged: playerToolbarVisibilityFSM.mouseMove()
                }
            }
        }
    }

    // Title bar slot: the main window title bar (LocalTopbar, owned by the
    // window chrome) with the player hooks. The side panel toggle of the title
    // bar drives MainCtx.playerSidePanelVisible.
    Item {
        id: titleBarArea

        width: parent.width
        height: VLCStyle.titleBar_height

        y: rootPlayer.chromeVisible ? 0 : -height
        visible: y > -height

        z: 2

        Behavior on y {
            NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.InOutSine }
        }

        focus: true

        LocalTopbar {
            id: topBar

            anchors.fill: parent

            useAcrylic: false

            focus: true

            navigationVisible: MainCtx.playerSidePanelVisible
            playqueueVisible: playlistVisibility.isPlaylistVisible

            plListView: {
                if (playlistpopup.active)
                    return playlistpopup.item
                else if (playlistWindowLoader?.status === Loader.Ready)
                    return playlistWindowLoader.item.playlistView
                else
                    return null
            }

            onToggleNavigationVisibility: MainCtx.playerSidePanelVisible = !MainCtx.playerSidePanelVisible
            onTogglePlayqueueVisibility: playlistVisibility.togglePlaylistVisibility()

            Navigation.parentItem: rootPlayer
            Navigation.downItem: {
                if (playlistVisibility.isPlaylistVisible)
                    return playlistpopup
                if (MainCtx.hasEmbededVideo)
                    return playerSpecializationLoader
                if (Player.isInteractive)
                    return toggleControlBarButton
                return controlBar
            }
        }

        // customizable slots of the title bar get outlined by the title bar
        // itself (MainCtx.playerCustomizeMode); outline the whole bar as a
        // fallback when it does not
        DashedOutline {
            anchors.fill: parent
            anchors.margins: VLCStyle.space_4
            visible: MainCtx.playerCustomizeMode && !(topBar.customizeOutlines ?? false)
            color: windowTheme.palette.fgA4
        }
    }

    // Docked library side panel (rail + panel), needs the media library
    Loader {
        id: sidePanel

        width: VLCStyle.playerSidePanel_width

        x: rootPlayer.sidePanelShown ? 0 : -width
        y: contentArea.y
        height: contentArea.height

        visible: x > -width
        active: MainCtx.mediaLibraryAvailable && (visible || MainCtx.playerSidePanelVisible)

        z: 1

        Behavior on x {
            NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.InOutSine }
        }

        source: "qrc:///qt/qml/VLC/Player/PlayerSidePanel.qml"

        Connections {
            target: sidePanel.item
            function onActiveFocusChanged() {
                if (sidePanel.item.activeFocus)
                    playerToolbarVisibilityFSM.mouseMove()
            }
        }

        Navigation.parentItem: rootPlayer
        Navigation.rightItem: playerSpecializationLoader
        Navigation.upItem: titleBarArea
        Navigation.downItem: controlBar
    }

    Loader {
        id: playlistpopup

        // NOTE: the play queue is docked on the right of the video area
        y: contentArea.y
        height: contentArea.height
        x: rootPlayer.width - width

        focus: false

        active: MainCtx.playqueuePanel.docked && !MainCtx.playerCustomizeMode

        //initial state value is "", using a binding avoid animation on startup
        Binding on state {
            when: playlistVisibility.started
            value: (playlistpopup.status === Loader.Ready && playlistVisibility.isPlaylistVisible && rootPlayer.chromeVisible) ? "expanded" : "retracted"
        }

        Component.onCompleted: {
            Qt.callLater(() => { playlistTransition.enabled = true; })
        }

        states: [
            State {
                name: "expanded"
                PropertyChanges {
                    target: playlistpopup
                    width: playlistpopup.implicitWidth
                    visible: true
                }
           }, State {
                name: "retracted"
                PropertyChanges {
                    target: playlistpopup
                    width: 0
                    visible: false
                }
           }
        ]

        transitions: Transition {
            id: playlistTransition
            enabled: false

            from: "retracted"; to: "expanded";
            reversible: true

            SequentialAnimation {
                PropertyAction { property: "visible" }

                NumberAnimation {
                    property: "width"
                    duration: VLCStyle.duration_short
                    easing.type: Easing.InOutSine
                }
            }
        }

        sourceComponent: PlaylistPane {
            id: playlistView

            property real maximumWidth: (rootPlayer.width + playlistView.rightPadding) / 2

            implicitWidth: Helpers.clamp(MainCtx.playqueuePanel.width
                                 , playlistView.minimumWidth
                                 , playlistView.maximumWidth)
            height: playlistpopup.height

            useAcrylic: false
            focus: true

            wheelEnabled: true

            rightPadding: VLCStyle.windowPadding
            topPadding: VLCStyle.margin_normal
            bottomPadding: 0

            background: Rectangle {
                color: windowTheme.palette.isDark ? windowTheme.palette.bgB1 : windowTheme.palette.bgA3
            }

            Navigation.parentItem: rootPlayer
            Navigation.upItem: titleBarArea
            Navigation.downItem: Player.isInteractive ? toggleControlBarButton : controlBar
            Navigation.leftAction: closePlaylist
            Navigation.cancelAction: closePlaylist

            function closePlaylist() {
                playlistVisibility.togglePlaylistVisibility()
                controlBar.forceActiveFocus()
            }


            Widgets.HorizontalResizeHandle {
                id: resizeHandle

                property bool _inhibitMainCtxUpdate: false

                parent: playlistView

                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                }

                atRight: false
                currentWidth: playlistpopup.width

                maximumWidth: playlistView.maximumWidth
                minimumWidth: playlistView.minimumWidth

                onRequestedWidthChanged: {
                    if (!_inhibitMainCtxUpdate)
                        MainCtx.playqueuePanel.width = requestedWidth
                }

                Component.onCompleted:  _updateFromMainCtx()

                function _updateFromMainCtx() {
                    if (requestedWidth === MainCtx.playqueuePanel.width)
                        return

                    _inhibitMainCtxUpdate = true
                    requestedWidth = MainCtx.playqueuePanel.width
                    _inhibitMainCtxUpdate = false
                }

                Connections {
                    target: MainCtx.playqueuePanel

                    function onWidthChanged() {
                        resizeHandle._updateFromMainCtx()
                    }
                }
            }
        }
    }

    // "continue" toast (resume playback)
    ResumeDialog {
        id: resumeDialog

        z: 3

        anchors.horizontalCenter: contentArea.horizontalCenter
        y: contentArea.y + contentArea.height - height - VLCStyle.dp(24, VLCStyle.scale)

        maxWidth: Math.min(VLCStyle.dp(519, VLCStyle.scale), contentArea.width - VLCStyle.space_20 * 2)

        Navigation.parentItem: rootPlayer

        onVisibleChanged: rootPlayer.lockUnlockAutoHide(visible)
    }

    Dialogs {
        z: 10
        bgContent: rootPlayer

        toolbarEditorHandler: rootPlayer.enterCustomizeMode

        anchors {
            bottom: controlBar.top
            left: parent.left
            right: parent.right
        }
    }

    Timer {
        // NavigationBox's visibility depends on this timer
        id: interactiveAutoHideTimer
        running: false
        repeat: false
        interval: 3000
    }

    NavigationBox {
        id: navBox
        visible: Player.isInteractive && navBox.show
                    && (interactiveAutoHideTimer.running
                    || navBox.hovered || !MainCtx.hasEmbededVideo)

        x: rootPlayer.x + VLCStyle.margin_normal + VLCStyle.applicationHorizontalMargin
        y: controlBar.y - navBox.height - VLCStyle.margin_normal

        dragXMin: 0
        dragXMax: rootPlayer.width - navBox.width
        dragYMin: 0
        dragYMax: rootPlayer.height - navBox.height

        Drag.onDragStarted: (controlId) => {
            navBox.x = drag.x
            navBox.y = drag.y
        }
    }

    Connections {
        target: MainCtx
        function onNavBoxToggled() { interactiveAutoHideTimer.restart() }
    }

    Connections {
        target: rootPlayer
        function onWidthChanged() {
            if (navBox.x > navBox.dragXMax)
                navBox.x = navBox.dragXMax
        }
        function onHeightChanged() {
            if (navBox.y > navBox.dragYMax)
                navBox.y = navBox.dragYMax
        }
    }

    Widgets.ButtonExt {
        id: toggleControlBarButton
        visible: Player.isInteractive
                 && MainCtx.hasEmbededVideo
                 && !(MainCtx.pinVideoControls && !Player.fullscreen)
                 && (interactiveAutoHideTimer.running === true
                     || rootPlayer.chromeVisible || toggleControlBarButton.hovered)
        focus: true
        anchors {
            bottom: rootPlayer.chromeVisible ? controlBar.top : parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        iconSize: VLCStyle.icon_large
        iconTxt: rootPlayer.chromeVisible ? VLCIcons.expand : VLCIcons.expand_inverted

        Navigation.parentItem: rootPlayer
        Navigation.upItem: playlistVisibility.isPlaylistVisible ? playlistpopup : (MainCtx.hasEmbededVideo ? playerSpecializationLoader : titleBarArea)
        Navigation.downItem: controlBar

        onClicked:{
            playerToolbarVisibilityFSM.askShow();
        }
    }

    Widgets.FloatingNotification {
        id: notif

        anchors {
            bottom: controlBar.top
            left: parent.left
            right: parent.right
            margins: VLCStyle.margin_large
        }
    }

    PlayerControlBar {
        id: controlBar

        width: parent.width
        y: rootPlayer.chromeVisible ? rootPlayer.height - height : rootPlayer.height
        visible: y < rootPlayer.height

        z: 2

        Behavior on y {
            NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.InOutSine }
        }

        hoverEnabled: true

        focus: true

        musicMode: rootPlayer.musicMode
        customizeMode: MainCtx.playerCustomizeMode
        customizeDragLayer: customizeDragLayer

        identifier: (Player.hasVideoOutput) ? PlayerControlbarModel.Videoplayer
                                            : PlayerControlbarModel.Audioplayer

        onVisibleChanged: {
            if (visible)
                showChapterMarks()
        }

        Navigation.parentItem: rootPlayer
        Navigation.upItem: {
            if (playlistVisibility.isPlaylistVisible)
                return playlistpopup
            if (Player.isInteractive)
                return toggleControlBarButton
            if (!MainCtx.hasEmbededVideo)
                return playerSpecializationLoader
            return titleBarArea
        }

        onRequestLockUnlockAutoHide: (lock) => rootPlayer.lockUnlockAutoHide(lock)

        onHoveredChanged: rootPlayer.lockUnlockAutoHide(hovered)
    }

    // "Customize Player": modal + drag layer
    Loader {
        id: customizeDialogLoader

        active: MainCtx.playerCustomizeMode

        z: 20

        x: (rootPlayer.width - width) / 2
        y: Math.max(titleBarArea.height + VLCStyle.space_20,
                    titleBarArea.height + (controlBar.y - titleBarArea.height - height) / 2)

        sourceComponent: PlayerCustomizeDialog {
            dragLayer: customizeDragLayer

            maximumHeight: controlBar.y - titleBarArea.height - VLCStyle.space_20 * 2

            onFinished: MainCtx.playerCustomizeMode = false
        }
    }

    PlayerCustomizeDragLayer {
        id: customizeDragLayer

        anchors.fill: parent
        z: 30

        visible: MainCtx.playerCustomizeMode
    }

    QmlAudioContextMenu {
        id: audioContextMenu

        ctx: MainCtx
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: !MainCtx.hasEmbededVideo

        onTapped: (eventPoint, button) => {
            if (button & Qt.RightButton) {
                audioContextMenu.popup(eventPoint.globalPosition)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        propagateComposedEvents: true
        cursorShape: undefined
        onClicked: {
            MainCtx.playerView = false
        }
    }

    // any pointer move over the page shows the chrome (video surface mouse
    // events are handled by the VideoSurface)
    HoverHandler {
        onPointChanged: {
            if (!rootPlayer.chromeVisible && !MainCtx.playerHideUI)
                playerToolbarVisibilityFSM.mouseMove()
        }
    }

    //filter key events to keep toolbar
    //visible when user navigates within the control bar
    KeyEventFilter {
    id: filter
    target: MainCtx.intfMainWindow

        Keys.onPressed: (event) => {
            if (Player.isInteractive)
                interactiveAutoHideTimer.restart()
            else
                playerToolbarVisibilityFSM.keyboardMove()
        }
    }
}
