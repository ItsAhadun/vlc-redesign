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
import QtQuick.Layouts
import QtQuick.Templates as T
import QtQuick.Window

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.Player
import VLC.Playlist
import VLC.Dialogs

// Floating mini player card (design/SPEC.md 2.2, component 970:3091):
// 391x339 BG/A3 card docked 8 px from the bottom-right (or bottom-left)
// corner: video preview / artwork, progress strip, title, folder and artist
// chips, queue toggle. The queue expands above the card (391x690).
// Hovering the preview shows close, pop-out and prev / play / next (replay
// when the media ended). Clicking the card opens the player. The card can be
// dragged to the other side of the window, the side is remembered.
T.Control {
    id: root

    // the ColorContext palette is null until it is inherited from a parent context
    readonly property var _palette: theme.palette ?? VLCStyle.palette

    // Properties

    // dock side, persisted in the interface settings
    property bool dockRight: true

    // item used to compute the dock side while dragging
    property Item dragArea: parent

    property bool queueExpanded: false

    // the media ended: the card stays with a replay button until closed
    property bool _ended: false

    readonly property bool _hasVideoSurface: MainCtx.canShowVideoPIP && MainCtx.hasEmbededVideo
                                             && Player.hasVideoOutput

    readonly property string _settingKey: "MainWindow/miniPlayerDock"

    // Settings

    implicitWidth: VLCStyle.miniPlayer_width
    implicitHeight: VLCStyle.miniPlayer_height + (queueExpanded ? queueHeight : 0)

    readonly property int queueHeight: VLCStyle.dp(351, VLCStyle.scale)

    width: implicitWidth
    height: implicitHeight

    padding: VLCStyle.space_8

    visible: Player.isStarted || root._ended
    enabled: visible

    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Mini player")
    AccessibleCompat.id: "miniPlayer"

    Behavior on height {
        enabled: theme.initialized
        NumberAnimation { duration: VLCStyle.duration_short; easing.type: Easing.InOutSine }
    }

    Component.onCompleted: {
        root.dockRight = (MainCtx.settingValue(_settingKey, "right") !== "left")
    }

    onDockRightChanged: MainCtx.setSettingValue(_settingKey, dockRight ? "right" : "left")

    // last known position, the player resets it when stopping
    property real _lastPosition: 0

    Connections {
        target: Player

        function onPositionChanged() {
            if (Player.isStarted)
                root._lastPosition = Player.position
        }

        function onPlayingStateChanged() {
            if (Player.playingState === Player.PLAYING_STATE_STOPPED) {
                // keep the card with a replay button when the media reached its end
                root._ended = (root._lastPosition > 0.95) && !MainPlaylistController.empty
            } else if (Player.isStarted) {
                root._ended = false
            }
        }
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // Functions

    function openPlayer() {
        if (root._ended)
            MainPlaylistController.play()
        MainCtx.playerView = true
    }

    // Children

    // dragging the card moves it horizontally, it docks to the nearest side
    transform: Translate { id: dragTranslate }

    DragHandler {
        id: dragHandler

        target: null
        yAxis.enabled: false
        cursorShape: active ? Qt.ClosedHandCursor : undefined

        onTranslationChanged: dragTranslate.x = translation.x

        onActiveChanged: {
            if (active)
                return

            const center = root.x + dragTranslate.x + root.width / 2
            root.dockRight = (center > (root.dragArea ? root.dragArea.width / 2 : center))
            dragTranslate.x = 0
        }
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.openPlayer()
    }

    background: Rectangle {
        radius: VLCStyle.radius_large
        color: root._palette.bgA3

        Widgets.RoundedRectangleShadow {
            blurRadius: VLCStyle.popupShadow_blurRadius
            yOffset: VLCStyle.popupShadow_yOffset
            color: VLCStyle.popupShadow_color
        }
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Queue (Variant2): header, count + sort / - / +, rows
        Loader {
            id: queueLoader

            Layout.fillWidth: true
            Layout.preferredHeight: root.queueExpanded ? root.queueHeight : 0
            Layout.topMargin: -root.topPadding
            Layout.leftMargin: -root.leftPadding
            Layout.rightMargin: -root.rightPadding

            visible: Layout.preferredHeight > 0
            clip: true

            active: root.queueExpanded
            sourceComponent: queueComponent
        }

        // Preview: live video when the compositor can show it, artwork otherwise
        Rectangle {
            id: preview

            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(width * 9 / 16)

            radius: VLCStyle.radius_medium
            color: root._palette.bgB2
            clip: true

            Loader {
                anchors.fill: parent
                active: root._hasVideoSurface
                sourceComponent: VideoSurface {
                    videoSurfaceProvider: MainCtx.videoSurfaceProvider
                }
            }

            // artwork (audio), or a video glyph when the video can not be shown here
            Widgets.ImageExt {
                id: artwork

                anchors.fill: parent

                visible: !root._hasVideoSurface && status === Image.Ready
                radius: preview.radius

                source: {
                    const art = Player.artwork?.toString() ?? ""
                    return (art.length > 0) ? VLCAccessImage.uri(art) : ""
                }
                sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Widgets.IconLabel {
                anchors.centerIn: parent
                visible: !root._hasVideoSurface && !artwork.visible && !previewHover.hovered
                // TODO(icons): redesign "video" / "music" glyphs
                text: Player.hasVideoOutput ? VLCIcons.topbar_video : VLCIcons.topbar_music
                font.pixelSize: VLCStyle.dp(48, VLCStyle.scale)
                color: root._palette.fgA4
            }

            HoverHandler {
                id: previewHover
            }

            // Hover (Variant3/4/5): scrim, close, pop-out, prev / play / next or replay
            Item {
                anchors.fill: parent

                visible: previewHover.hovered || closeButton.visualFocus || popOutButton.visualFocus
                         || playButton.visualFocus || prevButton.visualFocus || nextButton.visualFocus
                         || MainCtx.usingTouch

                Rectangle {
                    anchors.fill: parent
                    color: VLCStyle.darkPalette.bgB2Transparent
                    opacity: 0.6
                }

                OverlayButton {
                    id: closeButton

                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: VLCStyle.space_6

                    text: VLCIcons.close
                    description: qsTr("Close")
                    onClicked: {
                        root._ended = false
                        MainPlaylistController.stop()
                    }
                }

                OverlayButton {
                    id: popOutButton

                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: VLCStyle.space_6

                    // TODO(icons): redesign "pop-out" glyph
                    text: VLCIcons.fullscreen
                    description: qsTr("Open player")
                    onClicked: root.openPlayer()
                }

                Row {
                    anchors.centerIn: parent
                    spacing: VLCStyle.space_16

                    OverlayButton {
                        id: prevButton
                        visible: !root._ended
                        text: VLCIcons.previous
                        description: qsTr("Previous")
                        enabled: MainPlaylistController.hasPrev
                        onClicked: MainPlaylistController.prev()
                    }

                    OverlayButton {
                        id: playButton

                        font.pixelSize: VLCStyle.dp(32, VLCStyle.scale)

                        text: root._ended ? VLCIcons.ic_fluent_arrow_sync_24_regular // TODO(icons): "replay"
                                          : ((Player.playingState === Player.PLAYING_STATE_PLAYING)
                                             ? VLCIcons.pause_filled : VLCIcons.play_filled)
                        description: root._ended ? qsTr("Replay")
                                                 : qsTr("Play/Pause")
                        onClicked: {
                            if (root._ended)
                                MainPlaylistController.play()
                            else
                                MainPlaylistController.togglePlayPause()
                        }
                    }

                    OverlayButton {
                        id: nextButton
                        visible: !root._ended
                        text: VLCIcons.next
                        description: qsTr("Next")
                        enabled: MainPlaylistController.hasNext
                        onClicked: MainPlaylistController.next()
                    }
                }
            }
        }

        // Progress strip: BG/B2 track, BG/Accent Bright played part,
        // Accent/Main handle on hover; click or drag to seek
        Item {
            id: progress

            Layout.fillWidth: true
            Layout.topMargin: VLCStyle.space_4
            Layout.preferredHeight: VLCStyle.space_12

            readonly property real value: root._ended ? 1.0 : Helpers.clamp(Player.position, 0, 1)

            Rectangle {
                anchors.fill: parent
                radius: VLCStyle.radius_medium
                color: root._palette.bgB2
            }

            Rectangle {
                width: Math.max(height, parent.width * progress.value)
                height: parent.height
                radius: VLCStyle.radius_medium
                color: root._palette.bgAccentBright
                visible: progress.value > 0
            }

            Rectangle {
                x: Helpers.clamp(parent.width * progress.value - width / 2, 0, parent.width - width)
                width: VLCStyle.seekHandle_width
                height: parent.height
                radius: VLCStyle.radius_xxsmall
                color: root._palette.accentMain
                visible: progressMouse.containsMouse || progressMouse.pressed
            }

            MouseArea {
                id: progressMouse

                anchors.fill: parent
                anchors.topMargin: -VLCStyle.space_4
                anchors.bottomMargin: -VLCStyle.space_4

                hoverEnabled: true
                enabled: Player.seekable

                function _seek(x) {
                    Player.position = Helpers.clamp(x / width, 0, 1)
                }

                onPressed: (mouse) => _seek(mouse.x)
                onPositionChanged: (mouse) => { if (pressed) _seek(mouse.x) }
            }
        }

        Text {
            id: titleLabel

            Layout.fillWidth: true
            Layout.topMargin: VLCStyle.dp(17, VLCStyle.scale)
            Layout.leftMargin: VLCStyle.space_8
            Layout.rightMargin: VLCStyle.space_8

            text: Player.title || Player.name || ""
            elide: Text.ElideRight
            font.pixelSize: VLCStyle.fontSize_body
            color: root._palette.fgA2
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: VLCStyle.space_6
            Layout.rightMargin: VLCStyle.space_2

            spacing: VLCStyle.space_16

            // folder of the current media
            Chip {
                readonly property string folder: {
                    const url = MainPlaylistController.currentItem?.url?.toString() ?? ""
                    const parts = url.split("/").filter((p) => p.length > 0)
                    return parts.length > 1 ? decodeURIComponent(parts[parts.length - 2]) : ""
                }

                visible: folder.length > 0
                label: folder
                folderGlyph: true
            }

            // artist (audio) or album
            Chip {
                readonly property string artist: Player.artist || Player.album || ""

                visible: artist.length > 0
                label: artist
                // TODO(icons): redesign "artist" glyph
                iconText: VLCIcons.profile_new
            }

            Item {
                Layout.fillWidth: true
            }

            Widgets.IconToolButton {
                id: queueButton

                Layout.preferredWidth: VLCStyle.iconWrapper_width
                Layout.preferredHeight: VLCStyle.iconWrapper_height

                // TODO(icons): redesign "queue" glyph
                text: VLCIcons.playlist
                description: root.queueExpanded ? qsTr("Hide the queue") : qsTr("Show the queue")
                font.pixelSize: VLCStyle.icon_normal
                radius: VLCStyle.radius_small
                checked: root.queueExpanded
                color: checked ? root._palette.accentMain : root._palette.fgA2

                onClicked: root.queueExpanded = !root.queueExpanded

                Navigation.parentItem: root
            }
        }
    }

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => {
        if (KeyHelper.matchOk(event)) {
            root.openPlayer()
            event.accepted = true
            return
        }
        Navigation.defaultKeyAction(event)
    }

    // Queue panel
    Component {
        id: queueComponent

        Item {
            id: queue

            PlaylistListModel {
                id: queueModel
                playlist: MainPlaylistController.playlist
            }

            property int selectedIndex: -1

            // "2h 3m", "24m", "40s"
            function formatDuration(duration) {
                const total = duration?.toSeconds() ?? 0
                const h = Math.floor(total / 3600)
                const m = Math.floor((total % 3600) / 60)
                if (h > 0)
                    return qsTr("%1h %2m").arg(h).arg(m)
                if (m > 0)
                    return qsTr("%1m").arg(m)
                return qsTr("%1s").arg(total)
            }

            // header band
            Rectangle {
                id: queueHeader

                anchors.left: parent.left
                anchors.right: parent.right
                height: VLCStyle.dp(41, VLCStyle.scale)

                radius: VLCStyle.radius_large
                color: root._palette.bgA4

                // square bottom corners
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.radius
                    color: parent.color
                }

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Queue")
                    font.pixelSize: VLCStyle.fontSize_body
                    color: root._palette.fgA2
                }
            }

            RowLayout {
                id: queueToolbar

                anchors.top: queueHeader.bottom
                anchors.topMargin: VLCStyle.space_14
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: VLCStyle.space_20
                anchors.rightMargin: VLCStyle.space_12

                height: VLCStyle.iconWrapper_height
                spacing: VLCStyle.space_6

                Text {
                    Layout.fillWidth: true
                    text: ((queueModel.count === 1) ? qsTr("1 item") : qsTr("%1 items").arg(queueModel.count))
                          + (queueModel.count > 0 ? " · " + queue.formatDuration(queueModel.duration) : "")
                    elide: Text.ElideRight
                    font.pixelSize: VLCStyle.fontSize_body
                    color: root._palette.fgA3
                }

                Widgets.SortControl {
                    Layout.preferredWidth: VLCStyle.iconWrapper_width
                    Layout.preferredHeight: VLCStyle.iconWrapper_height

                    radius: VLCStyle.radius_small
                    enabled: MainPlaylistController.count > 1
                    popupAbove: false

                    model: MainPlaylistController.sortKeyTitleList
                    sortKey: MainPlaylistController.sortKey
                    sortOrder: (MainPlaylistController.sortOrder === PlaylistController.SORT_ORDER_DESC)
                               ? Qt.DescendingOrder : Qt.AscendingOrder

                    onSortSelected: (key) => { MainPlaylistController.sortKey = key }
                    onSortOrderSelected: (type) => {
                        MainPlaylistController.sortOrder = (type === Qt.DescendingOrder)
                                ? PlaylistController.SORT_ORDER_DESC : PlaylistController.SORT_ORDER_ASC
                        MainPlaylistController.sort()
                    }
                }

                QueueButton {
                    // TODO(icons): redesign "minus" glyph
                    text: VLCIcons.remove
                    description: qsTr("Remove the selected item")
                    enabled: queueModel.count > 0
                    onClicked: {
                        const index = (queue.selectedIndex >= 0) ? queue.selectedIndex : queueModel.currentIndex
                        if (index >= 0)
                            queueModel.removeItems([index])
                        queue.selectedIndex = -1
                    }
                }

                QueueButton {
                    // TODO(icons): redesign "add" glyph
                    text: VLCIcons.add
                    description: qsTr("Add media to the queue")
                    onClicked: DialogsProvider.PLAppendDialog()
                }
            }

            ListView {
                id: queueList

                anchors.top: queueToolbar.bottom
                anchors.topMargin: VLCStyle.space_6
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: VLCStyle.space_8
                anchors.rightMargin: VLCStyle.space_8
                anchors.bottomMargin: VLCStyle.space_8

                clip: true
                model: queueModel
                boundsBehavior: Flickable.StopAtBounds

                T.ScrollBar.vertical: Widgets.ScrollBarExt { }

                delegate: T.ItemDelegate {
                    id: row

                    required property int index
                    required property string title
                    required property var duration
                    required property bool isCurrent

                    width: ListView.view.width
                    height: VLCStyle.dp(44, VLCStyle.scale)

                    leftPadding: VLCStyle.space_12
                    rightPadding: VLCStyle.space_14

                    highlighted: queue.selectedIndex === index

                    onClicked: queue.selectedIndex = index
                    onDoubleClicked: MainPlaylistController.goTo(index, true)

                    background: Rectangle {
                        radius: VLCStyle.radius_small
                        color: row.highlighted ? root._palette.bgA1
                                               : (row.hovered ? root._palette.hoverOverlay : "transparent")
                    }

                    contentItem: RowLayout {
                        spacing: VLCStyle.space_14

                        // drag handle ("move"): two short lines
                        // TODO(icons): redesign "move" glyph; drag and drop reordering
                        Column {
                            Layout.preferredWidth: VLCStyle.icon_normal
                            spacing: VLCStyle.space_4
                            Repeater {
                                model: 2
                                Rectangle {
                                    x: VLCStyle.space_6
                                    width: VLCStyle.space_12
                                    height: VLCStyle.border * 2
                                    radius: height / 2
                                    color: root._palette.fgA3
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.title
                            elide: Text.ElideRight
                            font.pixelSize: VLCStyle.fontSize_body
                            color: row.isCurrent ? root._palette.accentMain : root._palette.fgA2
                        }

                        Text {
                            text: row.duration?.formatHMS() ?? ""
                            font.pixelSize: VLCStyle.fontSize_body
                            color: root._palette.fgA3
                        }
                    }
                }
            }
        }
    }

    // white glyph buttons over the video
    component OverlayButton: Widgets.IconToolButton {
        width: VLCStyle.iconWrapper_height
        height: VLCStyle.iconWrapper_height
        font.pixelSize: VLCStyle.icon_normal
        radius: VLCStyle.radius_small
        color: enabled ? VLCStyle.darkPalette.fg1 : VLCStyle.darkPalette.fgA3
    }

    component QueueButton: Widgets.IconToolButton {
        Layout.preferredWidth: VLCStyle.iconWrapper_width
        Layout.preferredHeight: VLCStyle.iconWrapper_height
        font.pixelSize: VLCStyle.icon_normal
        radius: VLCStyle.radius_small
    }

    // icon + label (folder, artist)
    component Chip: Row {
        property string label
        property string iconText: ""
        property bool folderGlyph: false

        spacing: VLCStyle.space_6

        Widgets.FolderIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: parent.folderGlyph
            color: root._palette.fgA2
        }

        Widgets.IconLabel {
            anchors.verticalCenter: parent.verticalCenter
            visible: !parent.folderGlyph
            text: parent.iconText
            font.pixelSize: VLCStyle.icon_normal
            color: root._palette.fgA2
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            elide: Text.ElideRight
            width: Math.min(implicitWidth, VLCStyle.dp(120, VLCStyle.scale))
            font.pixelSize: VLCStyle.fontSize_body
            color: root._palette.fgA2
        }
    }
}
