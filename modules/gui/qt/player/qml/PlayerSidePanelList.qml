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
import VLC.MediaLibrary
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs
import VLC.Util

// Compact list page of the player side panel (design/SPEC.md 3.12 "media" /
// "playlist" rows, 337x32): thumbnail 24 + name, watched items in FG/A2,
// unwatched dimmed, the playing item in Accent/Main.
//
// Generic over the media library models: `kind` selects the model, `parentId`
// drills into an album / playlist. Requires the media library.
// The library engineer can replace a section's page with a restyled view:
// a page must expose `count`, `model` (sortOrder / searchPattern) and the
// `drill(kind, parentId, title)` signal (see PlayerSidePanel.qml).
FocusScope {
    id: root

    // "recentVideos" | "recent" | "videos" | "albums" | "albumTracks" |
    // "playlists" | "playlistMedia"
    property string kind: "videos"
    property var parentId: undefined

    property bool showThumbnails: true

    readonly property int count: model ? model.count : 0
    readonly property var model: modelLoader.item

    signal drill(string kind, var parentId, string title)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    readonly property bool _isContainerList: kind === "albums" || kind === "playlists"

    function playAll() {
        if (!model || model.count === 0)
            return
        const indexes = []
        for (let i = 0; i < model.count; ++i)
            indexes.push(model.index(i, 0))
        model.addAndPlay(indexes)
    }

    Component { id: recentVideosModel; MLRecentVideoModel { ml: MediaLib } }
    Component { id: recentModel; MLRecentMediaModel { ml: MediaLib } }
    Component { id: videosModel; MLVideoModel { ml: MediaLib; sortCriteria: "title" } }
    Component { id: albumsModel; MLAlbumModel { ml: MediaLib; sortCriteria: "title" } }
    Component { id: albumTracksModel; MLAudioModel { ml: MediaLib; parentId: root.parentId; sortCriteria: "track_number" } }
    Component { id: playlistsModel; MLPlaylistListModel { ml: MediaLib } }
    Component { id: playlistMediaModel; MLPlaylistModel { ml: MediaLib; parentId: root.parentId } }

    Loader {
        id: modelLoader

        sourceComponent: {
            switch (root.kind) {
            case "recentVideos": return recentVideosModel
            case "recent": return recentModel
            case "albums": return albumsModel
            case "albumTracks": return albumTracksModel
            case "playlists": return playlistsModel
            case "playlistMedia": return playlistMediaModel
            case "videos":
            default: return videosModel
            }
        }
    }

    ListView {
        id: list

        anchors.fill: parent

        focus: true
        clip: true

        spacing: VLCStyle.space_10
        topMargin: VLCStyle.space_20
        bottomMargin: VLCStyle.space_20

        model: root.model
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: true

        T.ScrollBar.vertical: Widgets.ScrollBarExt { }

        header: Loader {
            width: list.width
            active: root.kind === "playlists"
            height: active ? VLCStyle.listRow_height + list.spacing : 0

            sourceComponent: Row {
                id: createRow

                height: VLCStyle.listRow_height
                spacing: VLCStyle.space_10

                readonly property bool _hovered: createHover.hovered

                HoverHandler { id: createHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        const dialog = DialogsProvider.getTextDialog(null, qsTr("Create playlist"),
                                                                     qsTr("Playlist name:"), "")
                        if (dialog.ok && dialog.text !== "")
                            root.model.create(dialog.text, [])
                    }
                }

                Item {
                    width: VLCStyle.listRow_height
                    height: VLCStyle.listRow_height

                    Widgets.IconLabel {
                        anchors.centerIn: parent
                        text: VLCIcons.add
                        color: createRow._hovered ? theme.palette.fgA2 : theme.palette.fgA3
                        font.pixelSize: VLCStyle.icon_normal
                    }
                }

                T.Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Create playlist")
                    color: createRow._hovered ? theme.palette.fgA2 : theme.palette.fgA4
                    font.pixelSize: VLCStyle.fontSize_body
                }
            }
        }

        delegate: T.ItemDelegate {
            id: row

            required property var model
            required property int index

            readonly property string _title: model.title || model.name || model.fileName || ""
            readonly property url _thumbnail: model.small_cover || model.thumbnail || model.cover || ""
            readonly property bool _isCurrent: !!model.mrl && (model.mrl.toString() === Player.url.toString())
            readonly property bool _watched: (model.progress !== undefined && model.progress > 0)
                                              || (model.playcount !== undefined && model.playcount > 0)
            readonly property bool _dimmed: !root._isContainerList && !_watched && !_isCurrent

            width: list.width
            height: VLCStyle.listRow_height

            hoverEnabled: true
            padding: 0

            highlighted: ListView.isCurrentItem && list.activeFocus

            background: Rectangle {
                radius: VLCStyle.radius_small
                color: (row.hovered || row.highlighted) ? theme.palette.hoverOverlay : "transparent"
            }

            contentItem: Row {
                spacing: VLCStyle.space_10

                Item {
                    width: VLCStyle.listRow_height
                    height: VLCStyle.listRow_height

                    // playlist / album glyph when there is no artwork
                    Widgets.IconLabel {
                        anchors.centerIn: parent
                        visible: !thumb.visible
                        text: root.kind === "playlists" ? VLCIcons.playlist
                                                        : (root.kind === "albums" ? VLCIcons.album_cover : VLCIcons.topbar_video)
                        color: theme.palette.fgA2
                        font.pixelSize: VLCStyle.icon_normal
                    }

                    Widgets.ImageExt {
                        id: thumb

                        anchors.fill: parent

                        visible: root.showThumbnails && row._thumbnail.toString() !== ""
                        source: visible ? row._thumbnail : ""
                        sourceSize: Qt.size(width * 2, height * 2)
                        fillMode: Image.PreserveAspectCrop
                        radius: VLCStyle.radius_xxsmall
                        asynchronous: true
                    }

                    // playing item: play glyph over the thumbnail
                    Rectangle {
                        anchors.fill: parent
                        visible: row._isCurrent
                        radius: VLCStyle.radius_xxsmall
                        color: Qt.rgba(0, 0, 0, 0.5)

                        Widgets.IconLabel {
                            anchors.centerIn: parent
                            text: VLCIcons.play_filled
                            color: theme.palette.accentMain
                            font.pixelSize: VLCStyle.icon_small
                        }
                    }

                    // watched progress tick
                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        visible: !root._isContainerList && model.progress !== undefined && model.progress > 0
                        width: parent.width * Math.min(1, Math.max(0, model.progress ?? 0))
                        height: VLCStyle.dp(2, VLCStyle.scale)
                        color: theme.palette.accentMain
                    }
                }

                T.Label {
                    width: row.width - VLCStyle.listRow_height - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter

                    text: row._title
                    elide: Text.ElideRight
                    font.pixelSize: VLCStyle.fontSize_body
                    color: row._isCurrent ? theme.palette.accentMain
                                          : (row._dimmed ? theme.palette.fgA3 : theme.palette.fgA2)
                }
            }

            onClicked: {
                list.currentIndex = index
                switch (root.kind) {
                case "albums":
                    root.drill("albumTracks", model.id, _title)
                    break
                case "playlists":
                    root.drill("playlistMedia", model.id, _title)
                    break
                default:
                    MediaLib.addAndPlay(model.id)
                    break
                }
            }

            Keys.onReturnPressed: clicked()
            Keys.onEnterPressed: clicked()
        }

        T.Label {
            anchors.centerIn: parent
            visible: list.count === 0 && !!root.model && !root.model.loading
            text: qsTr("No items")
            color: theme.palette.fgA3
            font.pixelSize: VLCStyle.fontSize_body
        }
    }
}
