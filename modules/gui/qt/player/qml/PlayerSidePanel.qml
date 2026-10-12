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
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Dialogs
import VLC.Util

// Docked library side panel of the player ("sidebar" component 848:1996,
// 427 wide = 50 px icon rail + 377 px panel), design/SPEC.md 2.1 frames
// 187:328 and 2425:13624.
//
// The rail selects a section (MainCtx.playerSidePanelPage), the panel shows a
// header (back / forward, title or breadcrumb, "..." = play all, pop-out =
// open in the library), a sub-header (item count, sort, view, search) and the
// section content. The content of a section is a page component (see
// `sections`); pages may drill down (album -> tracks), with a local history
// that does not touch the global navigation History.
FocusScope {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    readonly property url listPageUrl: "qrc:///qt/qml/VLC/Player/PlayerSidePanelList.qml"

    // rail entries; `kind` loads the generic compact list page, `action`
    // entries do not have a panel page. Restyled library views can replace
    // the page of a section by setting `url` (+ `properties`).
    property var sections: [
        { name: "home", icon: VLCIcons.home, title: qsTr("Home"), kind: "recentVideos", libraryPath: ["home"] },
        { name: "video", icon: VLCIcons.topbar_video, title: qsTr("Videos"), kind: "videos", libraryPath: ["video"] },
        { name: "music", icon: VLCIcons.topbar_music, title: qsTr("Music"), kind: "albums", libraryPath: ["music", "albums"] },
        { name: "network", icon: VLCIcons.topbar_network, title: qsTr("Network"), libraryPath: ["network"],
          action: () => root.openInLibrary(["network"]) },
        { name: "playlists", icon: VLCIcons.playlist, title: qsTr("Playlists"), kind: "playlists", libraryPath: ["playlists"] },
        { name: "recent", icon: VLCIcons.history, title: qsTr("Recent"), kind: "recent", libraryPath: ["recent"] },
        { name: "add", icon: VLCIcons.add, title: qsTr("Add"), action: () => DialogsProvider.simpleOpenDialog() }
    ]

    readonly property var currentSection: sections.find((s) => s.name === MainCtx.playerSidePanelPage)
                                          ?? sections[0]

    // local page history of the current section: [{ kind, parentId, title }]
    property var _pages: []
    property int _pageIndex: -1

    readonly property var _currentPage: (_pageIndex >= 0 && _pageIndex < _pages.length) ? _pages[_pageIndex] : null

    function openInLibrary(path) {
        MainCtx.playerView = false
        History.push(path)
    }

    function _resetPages() {
        const s = root.currentSection
        _pages = s.kind ? [{ kind: s.kind, parentId: undefined, title: s.title }] : []
        _pageIndex = _pages.length - 1
    }

    function _drill(kind, parentId, title) {
        const pages = _pages.slice(0, _pageIndex + 1)
        pages.push({ kind: kind, parentId: parentId, title: title })
        _pages = pages
        _pageIndex = pages.length - 1
    }

    Connections {
        target: MainCtx
        function onPlayerSidePanelPageChanged() { root._resetPages() }
    }

    Component.onCompleted: _resetPages()

    implicitWidth: VLCStyle.playerSidePanel_width

    // Rail
    Rectangle {
        id: rail

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left

        width: VLCStyle.navRail_width
        color: theme.palette.bgA4

        Column {
            anchors.top: parent.top
            anchors.topMargin: VLCStyle.space_10
            anchors.horizontalCenter: parent.horizontalCenter

            spacing: VLCStyle.space_14

            Repeater {
                model: root.sections

                delegate: Widgets.IconToolButton {
                    required property var modelData
                    required property int index

                    width: VLCStyle.iconButton_size + VLCStyle.space_4
                    height: VLCStyle.iconButton_size + VLCStyle.space_4

                    text: modelData.icon
                    description: modelData.title
                    font.pixelSize: VLCStyle.icon_normal

                    checked: !modelData.action && root.currentSection.name === modelData.name
                    color: checked ? theme.palette.accentMain : theme.palette.fgA2

                    focus: checked

                    onClicked: {
                        if (modelData.action)
                            modelData.action()
                        else
                            MainCtx.playerSidePanelPage = modelData.name
                    }
                }
            }
        }
    }

    // Panel
    Rectangle {
        id: panel

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: rail.right
        anchors.right: parent.right

        color: theme.palette.isDark ? theme.palette.bgB1 : theme.palette.bgA3

        readonly property real _hPadding: VLCStyle.space_20

        // Header: back / forward, title or breadcrumb, "...", pop-out
        Item {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: VLCStyle.space_20
            anchors.rightMargin: VLCStyle.space_20

            height: VLCStyle.dp(62, VLCStyle.scale)

            Row {
                id: historyButtons

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                spacing: VLCStyle.space_12

                Widgets.IconToolButton {
                    text: VLCIcons.back
                    description: qsTr("Back")
                    enabled: root._pageIndex > 0
                    font.pixelSize: VLCStyle.icon_normal
                    onClicked: root._pageIndex -= 1
                }

                Widgets.IconToolButton {
                    text: VLCIcons.back
                    description: qsTr("Forward")
                    rotation: 180
                    enabled: root._pageIndex < root._pages.length - 1
                    font.pixelSize: VLCStyle.icon_normal
                    onClicked: root._pageIndex += 1
                }
            }

            // breadcrumb: "… ▸ parent ▸ current"
            Row {
                anchors.left: historyButtons.right
                anchors.leftMargin: VLCStyle.space_10
                anchors.right: headerButtons.left
                anchors.rightMargin: VLCStyle.space_8
                anchors.verticalCenter: parent.verticalCenter

                spacing: VLCStyle.space_6
                clip: true

                Repeater {
                    model: {
                        const crumbs = root._pages.slice(0, root._pageIndex + 1).map((p) => p.title)
                        if (crumbs.length > 2)
                            return ["…", ...crumbs.slice(-2)]
                        return crumbs.length > 0 ? crumbs : [root.currentSection.title]
                    }

                    delegate: Row {
                        required property var modelData
                        required property int index

                        spacing: VLCStyle.space_6

                        Widgets.IconLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: index > 0
                            text: VLCIcons.breadcrumb_sep
                            color: theme.palette.fgA2
                            font.pixelSize: VLCStyle.icon_small
                        }

                        T.Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData
                            elide: Text.ElideRight
                            color: theme.palette.fgA2
                            font.pixelSize: VLCStyle.fontSize_body
                        }
                    }
                }
            }

            Row {
                id: headerButtons

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                spacing: VLCStyle.space_12

                Widgets.IconToolButton {
                    text: VLCIcons.ellipsis
                    description: qsTr("Play all")
                    font.pixelSize: VLCStyle.icon_normal
                    enabled: !!pageLoader.item && pageLoader.item.count > 0
                    onClicked: pageLoader.item?.playAll?.()
                }

                // TODO(icons): "open in new" icon of the redesign set
                Widgets.IconToolButton {
                    text: VLCIcons.fullscreen
                    description: qsTr("Open in the library")
                    font.pixelSize: VLCStyle.icon_normal
                    onClicked: root.openInLibrary(root.currentSection.libraryPath ?? ["home"])
                }
            }
        }

        // Sub-header: count, sort, view, search
        Item {
            id: subHeader

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: panel._hPadding
            anchors.rightMargin: panel._hPadding

            height: VLCStyle.dp(30, VLCStyle.scale)

            T.Label {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                text: pageLoader.item ? qsTr("%1 items").arg(pageLoader.item.count) : ""
                color: theme.palette.fgA3
                font.pixelSize: VLCStyle.fontSize_body
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                spacing: VLCStyle.space_12

                Widgets.IconToolButton {
                    text: VLCIcons.topbar_sort
                    description: qsTr("Sort order")
                    font.pixelSize: VLCStyle.icon_normal
                    enabled: !!pageLoader.item?.model
                    checked: pageLoader.item?.model?.sortOrder === Qt.DescendingOrder
                    onClicked: {
                        const m = pageLoader.item.model
                        m.sortOrder = (m.sortOrder === Qt.AscendingOrder) ? Qt.DescendingOrder : Qt.AscendingOrder
                    }
                }

                Widgets.IconToolButton {
                    text: VLCIcons.list
                    description: qsTr("Show thumbnails")
                    font.pixelSize: VLCStyle.icon_normal
                    enabled: !!pageLoader.item
                    onClicked: pageLoader.item.showThumbnails = !pageLoader.item.showThumbnails
                }

                Widgets.IconToolButton {
                    text: VLCIcons.search
                    description: qsTr("Search")
                    font.pixelSize: VLCStyle.icon_normal
                    checked: searchField.visible
                    enabled: !!pageLoader.item?.model
                    onClicked: {
                        searchField.visible = !searchField.visible
                        if (searchField.visible)
                            searchField.forceActiveFocus()
                        else {
                            searchField.text = ""
                        }
                    }
                }
            }
        }

        Widgets.TextFieldExt {
            id: searchField

            anchors.top: subHeader.bottom
            anchors.topMargin: VLCStyle.space_6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: panel._hPadding
            anchors.rightMargin: panel._hPadding

            visible: false
            height: visible ? VLCStyle.searchField_height : 0

            placeholderText: qsTr("Search")

            onTextChanged: {
                if (pageLoader.item?.model)
                    pageLoader.item.model.searchPattern = text
            }
        }

        Rectangle {
            id: divider

            anchors.top: searchField.visible ? searchField.bottom : subHeader.bottom
            anchors.topMargin: VLCStyle.space_12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: panel._hPadding
            anchors.rightMargin: panel._hPadding

            height: VLCStyle.dp(1, VLCStyle.scale)
            color: theme.palette.dividerDim
        }

        Loader {
            id: pageLoader

            anchors.top: divider.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: panel._hPadding
            anchors.rightMargin: panel._hPadding

            focus: true

            readonly property var _page: root._currentPage

            Component.onCompleted: _load()
            on_PageChanged: _load()

            function _load() {
                if (!_page) {
                    setSource("")
                    return
                }
                const s = root.currentSection
                const url = (s.url && root._pageIndex === 0) ? s.url : root.listPageUrl
                const props = Object.assign({ kind: _page.kind, parentId: _page.parentId }, s.properties ?? {})
                setSource(url, props)
            }

            Connections {
                target: pageLoader.item
                ignoreUnknownSignals: true
                function onDrill(kind, parentId, title) { root._drill(kind, parentId, title) }
            }
        }
    }
}
