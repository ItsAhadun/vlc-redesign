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
import QtQml.Models

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

// Compact media list (design/SPEC.md 2.1 list view, 3.12 side panel rows):
// rows of a small rounded thumbnail + name, laid out in as many columns as
// fit (row major). The playing media is shown in the accent color with a play
// glyph on its thumbnail; watched media are dimmed with an accent progress
// tick along the thumbnail bottom.
//
// Reusable outside the library (e.g. the player side panel: maxColumns: 1,
// thumbnailWidth/Height: 24, rowHeight: VLCStyle.listRow_height).
// Roles read from the model: thumbnailRole, titleRole, "progress", "isNew", "mrl".
GridView {
    id: root

    // the ColorContext palette is null until it is inherited from a parent context
    readonly property var _palette: theme.palette ?? VLCStyle.palette

    // Properties

    property ItemSelectionModel selectionModel: null

    property string thumbnailRole: "thumbnail"
    property string titleRole: "title"
    property url fallbackThumbnail: VLCStyle.noArtVideoCover

    property int thumbnailWidth: VLCStyle.dp(32, VLCStyle.scale)
    property int thumbnailHeight: VLCStyle.dp(24, VLCStyle.scale)
    property int rowHeight: VLCStyle.dp(42, VLCStyle.scale)

    property int minColumnWidth: VLCStyle.dp(360, VLCStyle.scale)
    property int maxColumns: 4

    // mrl of the media being played
    property string currentMrl: ""
    readonly property string _currentMrl: _normalizeMrl(currentMrl)

    // the media library and the playlist do not percent-encode the mrls the same way
    function _normalizeMrl(mrl) {
        const str = mrl?.toString() ?? ""
        try {
            return decodeURIComponent(str)
        } catch (e) {
            return str
        }
    }

    // extra padding (set by MainViewLoader), the list adds the layout margins
    property real leftPadding: 0
    property real rightPadding: 0

    readonly property int columns: Math.max(1, Math.min(maxColumns,
                                                        Math.floor(_availableWidth / minColumnWidth)))
    readonly property real _availableWidth: width - contentLeftMargin - contentRightMargin

    // the focus frame is only shown when navigating with the keyboard
    property bool _keyboardNavigation: false

    readonly property int contentLeftMargin: VLCStyle.layout_left_margin + leftPadding
    readonly property int contentRightMargin: VLCStyle.layout_right_margin + rightPadding

    // Signals

    signal itemActivated(int index)
    signal contextMenuRequested(int index, point globalPos)

    // Settings

    leftMargin: contentLeftMargin
    rightMargin: contentRightMargin

    // 1 px of slack so that the view never wraps a column because of rounding
    cellWidth: Math.floor((_availableWidth - 1) / columns)
    cellHeight: rowHeight

    clip: true
    focus: true
    activeFocusOnTab: true
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: true
    highlightFollowsCurrentItem: false

    T.ScrollBar.vertical: Widgets.ScrollBarExt { }

    Accessible.role: Accessible.List
    Accessible.name: qsTr("Media list")

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    // Functions

    function setCurrentItem(index) {
        currentIndex = index
        _select(index)
    }

    function setCurrentItemFocus(reason) {
        if (currentIndex < 0 && count > 0)
            setCurrentItem(0)
        forceActiveFocus(reason)
    }

    function _select(index) {
        if (!root.selectionModel || index < 0)
            return
        root.selectionModel.select(root.model.index(index, 0), ItemSelectionModel.ClearAndSelect)
    }

    // Events

    onCurrentIndexChanged: {
        if (activeFocus)
            _select(currentIndex)
    }

    Keys.onPressed: (event) => {
        root._keyboardNavigation = true
        if (KeyHelper.matchOk(event) && currentIndex >= 0) {
            root.itemActivated(currentIndex)
            event.accepted = true
        } else if (event.key === Qt.Key_Menu && currentItem) {
            root.contextMenuRequested(currentIndex, currentItem.mapToGlobal(0, currentItem.height))
            event.accepted = true
        }
    }

    Keys.onReleased: (event) => Navigation.defaultKeyReleaseAction(event)

    // Children

    delegate: T.ItemDelegate {
        id: row

        required property int index
        required property var model

        readonly property bool isCurrentMedia: root._currentMrl.length > 0
                                               && root._normalizeMrl(row.model.mrl) === root._currentMrl
        readonly property bool watched: (row.model.isNew === false)
        readonly property real progress: {
            const p = row.model.progress ?? 0
            return (p > 0) ? Helpers.clamp(p, 0, 1) : (row.watched ? 1.0 : 0.0)
        }
        readonly property bool selected: root.selectionModel?.selectedIndexesFlat?.includes(index)
                                         ?? (root.currentIndex === index)

        width: root.cellWidth
        height: root.cellHeight

        rightPadding: VLCStyle.space_16
        leftPadding: 0

        hoverEnabled: true

        Accessible.name: titleLabel.text

        onClicked: {
            root._keyboardNavigation = false
            root.currentIndex = index
            root._select(index)
            root.forceActiveFocus(Qt.MouseFocusReason)
        }

        onDoubleClicked: root.itemActivated(index)

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: (eventPoint) => {
                root.currentIndex = row.index
                root._select(row.index)
                root.contextMenuRequested(row.index, row.mapToGlobal(eventPoint.position.x, eventPoint.position.y))
            }
        }

        background: Rectangle {
            radius: VLCStyle.radius_small
            color: row.selected && root.activeFocus ? root._palette.bgA1
                                                    : (row.hovered ? root._palette.hoverOverlay : "transparent")
            border.width: (root.activeFocus && root._keyboardNavigation && root.currentIndex === row.index)
                          ? VLCStyle.focus_border : 0
            border.color: theme.visualFocus
        }

        contentItem: Item {
            Image {
                id: thumbnail

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                width: root.thumbnailWidth
                height: root.thumbnailHeight

                readonly property real radius: VLCStyle.radius_xxsmall

                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(width * 2, height * 2)

                source: {
                    const thumb = row.model[root.thumbnailRole]?.toString() ?? ""
                    return thumb.length > 0 ? thumb : root.fallbackThumbnail
                }

                // playing media: play glyph over a dim thumbnail
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    visible: row.isCurrentMedia
                    color: VLCStyle.darkPalette.bgB2Transparent
                    opacity: 0.6
                }

                Widgets.IconLabel {
                    anchors.centerIn: parent
                    visible: row.isCurrentMedia
                    text: VLCIcons.play_filled
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: root._palette.accentMain
                }

                // watched progress tick
                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: parent.width * row.progress
                    height: VLCStyle.dp(2, VLCStyle.scale)
                    visible: row.progress > 0 && !row.isCurrentMedia
                    color: root._palette.accentMain
                }
            }

            Text {
                id: titleLabel

                anchors.left: thumbnail.right
                anchors.leftMargin: VLCStyle.space_10
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                text: row.model[root.titleRole] ?? ""
                elide: Text.ElideRight
                font.pixelSize: VLCStyle.fontSize_body
                color: row.isCurrentMedia ? root._palette.accentMain
                                          : (row.watched ? root._palette.fgA3 : root._palette.fgA2)
            }
        }
    }
}
