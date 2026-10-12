/******************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
 *
 * Author: Ash <ashutoshv191@gmail.com>
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
 ******************************************************************************/
import QtQuick
import QtQuick.Window
import QtQuick.Templates as T

import VLC.MediaLibrary

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style

// Home (design/SPEC.md 2.1, 6261:15078): "Continue Watching", "Listen Again"
// and "Frequently Visited Folders" sections, each title opens the full list.
Widgets.PageExt {
    id: root

    // the ColorContext palette is null until it is inherited from a parent context
    readonly property var _palette: theme.palette ?? VLCStyle.palette

    property var pagePrefix: [] // behave like a Page

    property var sortModel: [
        { text: qsTr("Alphabetic"), criteria: "title" },
        { text: qsTr("Duration"), criteria: "duration" }
    ]

    title: qsTr("Home")

    hasGridListMode: true

    isSearchable: true

    // no "+" on Home
    addAction: null

    itemCount: -1

    property real listCoverHeight: VLCStyle.listAlbumCover_height
    property real listCoverWidth: VLCStyle.listAlbumCover_width
    property real listCoverRadius: VLCStyle.listAlbumCover_radius

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    signal seeAllButtonClicked(string name, int reason)

    function positionContentAtBeginning() {
        contentYBehavior.enabled = true
        flickable.contentY = -flickable.originY
        contentYBehavior.enabled = false
    }

    function setCurrentItemFocus(reason) {
        // `focus` is checked, because that indicates the item that has the focus within the focus scope
        if (listenAgainRow.focus)
            listenAgainRow.forceActiveFocus(reason)
        else if (foldersRow.focus)
            foldersRow.forceActiveFocus(reason)
        else if (continueWatchingRow.visible)
            continueWatchingRow.setCurrentItemFocus(reason)
        else if (listenAgainRow.visible)
            listenAgainRow.forceActiveFocus(reason)
        else
            foldersRow.forceActiveFocus(reason)
    }

    function _ensureVisible(item) {
        contentYBehavior.enabled = true
        Helpers.positionFlickableToContainItem(flickable, item)
        contentYBehavior.enabled = false
    }

    contentItem: Flickable {
        id: flickable

        implicitWidth: mediaRows.implicitWidth
        implicitHeight: mediaRows.implicitHeight

        contentWidth: width
        contentHeight: mediaRows.implicitHeight

        flickableDirection: Flickable.AutoFlickIfNeeded

        boundsBehavior: Flickable.StopAtBounds

        bottomMargin: VLCStyle.margin_large

        pixelAligned: (MainCtx.qtVersion() >= MainCtx.qtVersionCheck(6, 2, 5)) // QTBUG-103996
                      && (Screen.pixelDensity >= VLCStyle.highPixelDensityThreshold) // no need for sub-pixel alignment with high pixel density

        T.ScrollBar.vertical: Widgets.ScrollBarExt {}

        // This behavior allows to have similar "smooth" animation
        // that Qt views have with `highlightFollowsCurrentItem`.
        Behavior on contentY {
            id: contentYBehavior

            enabled: false

            // NOTE: Usage of `SmoothedAnimation` is intentional here.
            SmoothedAnimation {
                duration: VLCStyle.duration_veryLong
                easing.type: Easing.InOutSine
            }
        }

        property Component implicitFlickableScrollHandler: DefaultFlickableScrollHandler { }

        // NOTE: This property can be set to null to prevent using a scroll handler:
        property FlickableScrollHandler scrollHandler: {
            if (interactive) {
                // JS ownership:
                return implicitFlickableScrollHandler.createObject(null, { target: flickable })
            } else {
                return null
            }
        }

        Component.onCompleted: {
            if (!usingTouch) {
                // Flickable filters child mouse events for flicking (even when
                // the delegate is grabbed). However, this is not a useful
                // feature for non-touch cases, so disable it here and enable
                // it if touch is detected through the hover handler:
                MainCtx.setFiltersChildMouseEvents(flickable, false)
            }
        }

        readonly property bool usingTouch: MainCtx.usingTouch

        onUsingTouchChanged: {
            if (usingTouch)
                MainCtx.setFiltersChildMouseEvents(flickable, true)
            // We do not disable filtering child mouse events
            // because Qt currently has a bug that the flickable
            // jumps when it is enabled again later on.
        }

        Widgets.NavigableCol {
            id: mediaRows

            anchors.left: parent.left
            anchors.right: parent.right

            spacing: 0

            Navigation.parentItem: root
            Navigation.upItem: root.header

            // Continue Watching

            Widgets.ViewHeader {
                visible: continueWatchingRow.visible
                text: qsTr("Continue Watching")
                view: continueWatchingRow
                topPadding: 0
                bottomPadding: VLCStyle.space_14
                seeAllButton.visible: true

                onSeeAllButtonClicked: function (reason) {
                    root.seeAllButtonClicked("continueWatching", reason)
                }
            }

            VideoAll {
                id: continueWatchingRow

                AccessibleCompat.id: "continueWatching"

                anchors.left: parent.left
                anchors.right: parent.right

                height: currentItem?.contentHeight ?? implicitHeight

                visible: model.count !== 0

                headerPositioning: ListView.InlineHeader
                enableBeginningFade: false
                enableEndFade: false
                sectionProperty: ""

                interactive: false

                emptyLabel: null

                // FIXME: `ExpandGridView` causes extreme performance degradation when `reuseItems`
                //        is true and items provided by the model change (#29084).
                reuseItems: !MainCtx.gridView

                listCoverWidth: root.listCoverWidth
                listCoverHeight: root.listCoverHeight
                listCoverRadius: root.listCoverRadius

                Navigation.parentItem: mediaRows

                model: MLRecentVideoModel {
                    ml: MediaLib

                    sortCriteria: root.sort.criteria
                    sortOrder: root.sort.order
                    searchPattern: root.search.pattern

                    // FIXME: Make limit 0 load no items, instead of loading all items.
                    limit: MainCtx.gridView ? Math.max(continueWatchingRow.currentItem?.nbItemPerRow ?? null, 1) : 4
                }

                contextMenu: MLContextMenu {
                    model: continueWatchingRow.model

                    showPlayAsAudioAction: true
                }

                onActiveFocusChanged: {
                    if (activeFocus)
                        root._ensureVisible(this)
                }
            }

            SectionSpacer { visible: continueWatchingRow.visible }

            // Listen Again: the audio media of the playback history

            Widgets.ViewHeader {
                visible: listenAgainRow.visible
                text: qsTr("Listen Again")
                view: listenAgainRow
                topPadding: 0
                bottomPadding: VLCStyle.space_14
                seeAllButton.visible: true

                onSeeAllButtonClicked: function (reason) {
                    History.push(["recent"], reason)
                }
            }

            CardRow {
                id: listenAgainRow

                AccessibleCompat.id: "listenAgain"

                visible: contentWidth > 0

                model: MLRecentMediaModel {
                    id: recentModel
                    ml: MediaLib
                    limit: 30
                    searchPattern: root.search.pattern
                }

                cardHeight: VLCStyle.musicCard_size + VLCStyle.dp(19 + 17 + 4 + 17, VLCStyle.scale)

                delegate: MusicCard {
                    onActivated: MediaLib.addAndPlay(model.id)
                    onContextMenu: (globalPos) => recentContextMenu.popup([recentModel.index(index, 0)], globalPos)
                }

                MLContextMenu {
                    id: recentContextMenu
                    model: recentModel
                }

                onActiveFocusChanged: {
                    if (activeFocus)
                        root._ensureVisible(this)
                }

                Navigation.parentItem: mediaRows
            }

            SectionSpacer { visible: listenAgainRow.visible }

            // Frequently Visited Folders: the media library video folders

            Widgets.ViewHeader {
                visible: foldersRow.visible
                text: qsTr("Frequently Visited Folders")
                view: foldersRow
                topPadding: 0
                bottomPadding: VLCStyle.space_14
                seeAllButton.visible: true

                onSeeAllButtonClicked: function (reason) {
                    MainCtx.grouping = MainCtx.GROUPING_FOLDER
                    History.push(["video"], reason)
                }
            }

            CardRow {
                id: foldersRow

                AccessibleCompat.id: "frequentFolders"

                visible: count > 0

                model: MLVideoFoldersModel {
                    ml: MediaLib
                    searchPattern: root.search.pattern
                }

                cardHeight: VLCStyle.musicCard_size + VLCStyle.dp(19 + 17, VLCStyle.scale)

                delegate: FolderCard {
                    onActivated: History.push(["video", "all", "group"],
                                               { parentId: model.id, title: model.title },
                                               Qt.MouseFocusReason)
                }

                onActiveFocusChanged: {
                    if (activeFocus)
                        root._ensureVisible(this)
                }

                Navigation.parentItem: mediaRows
            }
        }
    }

    component SectionSpacer: Item {
        width: 1
        height: VLCStyle.dp(76, VLCStyle.scale)
    }

    // single row of fixed size cards, aligned with the grids
    component CardRow: ListView {
        id: cardRow

        property int cardHeight: VLCStyle.musicCard_size

        readonly property int contentLeftMargin: VLCStyle.layout_left_margin
        readonly property int contentRightMargin: VLCStyle.layout_right_margin

        anchors.left: parent?.left
        anchors.right: parent?.right

        height: cardHeight

        orientation: ListView.Horizontal
        interactive: false
        clip: true

        leftMargin: contentLeftMargin
        rightMargin: contentRightMargin

        focus: true
        activeFocusOnTab: true
        keyNavigationEnabled: true
        highlightFollowsCurrentItem: true

        Keys.priority: Keys.AfterItem
        Keys.onPressed: (event) => {
            if (KeyHelper.matchOk(event) && cardRow.currentItem) {
                cardRow.currentItem.activated()
                event.accepted = true
                return
            }
            Navigation.defaultKeyAction(event)
        }
    }

    // square music card: cover, title (FG/2), duration (FG/A3)
    component MusicCard: T.ItemDelegate {
        id: card

        required property var model
        required property int index

        signal activated()
        signal contextMenu(point globalPos)

        // video entries of the history are skipped
        readonly property bool _shown: model.isVideo === false

        visible: _shown
        width: _shown ? VLCStyle.musicCard_size + VLCStyle.card_spacing : 0
        height: ListView.view.height
        padding: 0
        rightPadding: VLCStyle.card_spacing

        onDoubleClicked: card.activated()
        onClicked: ListView.view.currentIndex = index

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: (eventPoint) => card.contextMenu(card.mapToGlobal(eventPoint.position.x, eventPoint.position.y))
        }

        Accessible.name: titleText.text

        background: null

        contentItem: Column {
            spacing: 0

            Widgets.ImageExt {
                width: VLCStyle.musicCard_size
                height: VLCStyle.musicCard_size

                radius: VLCStyle.radius_large
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(width * 2, height * 2)

                source: (card.model.small_cover?.toString() ?? "") || VLCStyle.noArtAlbumCover

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: card.visualFocus || (card.ListView.isCurrentItem && card.ListView.view.activeFocus)
                                  ? VLCStyle.focus_border * 2 : 0
                    border.color: theme.visualFocus
                }

                Widgets.PlayCover {
                    anchors.centerIn: parent
                    visible: card.hovered
                    onTapped: card.activated()
                }
            }

            Text {
                id: titleText

                topPadding: VLCStyle.dp(19, VLCStyle.scale) - VLCStyle.space_4
                width: VLCStyle.musicCard_size
                text: card.model.title || qsTr("Unknown title")
                elide: Text.ElideRight
                font.pixelSize: VLCStyle.fontSize_body
                color: (root._palette.isDark ? root._palette.fg2 : root._palette.fgA1)
            }

            Text {
                topPadding: VLCStyle.space_4
                width: VLCStyle.musicCard_size
                text: card.model.duration?.formatHMS() ?? ""
                elide: Text.ElideRight
                font.pixelSize: VLCStyle.fontSize_body
                color: root._palette.fgA3
            }
        }
    }

    // square BG/A2 card with a centered folder glyph
    component FolderCard: T.ItemDelegate {
        id: folderCard

        required property var model
        required property int index

        signal activated()

        width: VLCStyle.musicCard_size + VLCStyle.card_spacing
        height: ListView.view.height
        padding: 0
        rightPadding: VLCStyle.card_spacing

        hoverEnabled: true

        onClicked: folderCard.activated()

        Accessible.name: folderTitle.text

        background: null

        contentItem: Column {
            spacing: 0

            Rectangle {
                width: VLCStyle.musicCard_size
                height: VLCStyle.musicCard_size

                radius: VLCStyle.radius_large
                color: folderCard.hovered ? root._palette.bgA1 : root._palette.bgA2
                border.width: folderCard.visualFocus || (folderCard.ListView.isCurrentItem && folderCard.ListView.view.activeFocus)
                              ? VLCStyle.focus_border * 2 : 0
                border.color: theme.visualFocus

                Widgets.FolderIcon {
                    anchors.centerIn: parent
                    glyphSize: VLCStyle.dp(32, VLCStyle.scale)
                    color: root._palette.fgA2
                }
            }

            Text {
                id: folderTitle

                topPadding: VLCStyle.dp(19, VLCStyle.scale) - VLCStyle.space_4
                width: VLCStyle.musicCard_size
                text: folderCard.model.title ?? ""
                elide: Text.ElideRight
                font.pixelSize: VLCStyle.fontSize_body
                color: root._palette.fgA2
            }
        }
    }
}
