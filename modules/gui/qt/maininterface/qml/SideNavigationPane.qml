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
import QtQuick.Templates as T
import QtQml.Models

import VLC.Style
import VLC.Widgets as Widgets

import VLC.MainInterface
import VLC.Dialogs
import VLC.Util

// Library navigation pane (design/SPEC.md 2.1): a rounded BG/A4 card with
// Home, Videos, Music, Network, Playlists, Recent and "Add item".
// `collapsed` turns it into the icon-only rail used next to the player.
T.Pane {
    id: root

    // the ColorContext palette is null until it is inherited from a parent context
    readonly property var _palette: theme.palette ?? VLCStyle.palette

    signal itemClicked(uri : var, item : Item)

    // icon only rail
    property bool collapsed: false

    // the pane is drawn as an inset rounded card (library) or flat (player rail)
    property bool flat: false

    property alias model: navigationModel

    readonly property int minimumWidth: VLCStyle.navPane_width

    implicitWidth: collapsed ? VLCStyle.navRail_width : VLCStyle.navPane_width
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    padding: collapsed ? VLCStyle.space_4 : VLCStyle.space_6

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    Accessible.name: qsTr("Sidebar")

    NavigationModel {
        id: navigationModel
        hasMedialib: MainCtx.mediaLibraryAvailable
    }

    function _syncCurrentIndex() {
        for (let i = 0; i < listView.count; ++i) {
            const rowIndex = navigationModel.index(i, 0)
            const uri = navigationModel.data(rowIndex, NavigationModel.URI)

            if (uri && History.match(History.viewPath, uri)) {
                listView.currentIndex = i
                return
            }
        }
        listView.currentIndex = -1
    }

    Connections {
        target: History

        // NOTE: handles cases where the path changes not by clicking in the sidebar
        function onViewPathChanged(viewPath) {
            root._syncCurrentIndex()
        }
    }

    background: Rectangle {
        color: root._palette.bgA4
        radius: root.flat ? 0 : VLCStyle.radius_large
    }

    contentItem: ColumnLayout {
        spacing: 0

        Widgets.ListViewExt {
            id: listView

            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            Layout.maximumHeight: contentHeight

            interactive: false
            focus: true

            model: navigationModel

            fadingEdge.enableBeginningFade: false
            fadingEdge.enableEndFade: false

            colorContext.colorSet: ColorContext.Window

            reuseItems: false

            Component.onCompleted: root._syncCurrentIndex()
            onCountChanged: root._syncCurrentIndex()

            Navigation.parentItem: root
            Navigation.downItem: addItemButton

            delegate: SideNavigationDelegate {
                id: delegate

                width: ListView.view.width

                iconTxt: icon_alias
                text: title

                showText: !root.collapsed

                required property string title
                required property var uri
                // TODO: Qt 6.2 has property `icon` marked final, so we can't override it:
                required property string icon_alias

                required property int index

                accessibleId: {
                    const navBarIds = {
                        "home": "homeNavBar",
                        "video": "videoNavBar",
                        "music": "musicNavBar",
                        "network": "browseNavBar",
                        "playlists": "playlistsNavBar",
                        "recent": "recentNavBar"
                    }
                    return navBarIds[uri?.[0]] ?? ""
                }

                checked: !!uri && History.match(History.viewPath, uri)

                onClicked: {
                    root.itemClicked(uri, this)
                    listView.currentIndex = index
                    listView.forceActiveFocus(focusReason)
                }
            }
        }

        // "Add item": add a media folder to the library
        SideNavigationDelegate {
            id: addItemButton

            Layout.fillWidth: true

            visible: MainCtx.mediaLibraryAvailable

            accessibleId: "addItemNavBar"

            // TODO(icons): redesign "add" glyph
            iconTxt: VLCIcons.add
            text: qsTr("Add item")

            showText: !root.collapsed

            onClicked: DialogsProvider.addMediaLibraryFolder()

            Navigation.parentItem: root
            Navigation.upItem: listView

            Keys.priority: Keys.AfterItem
            Keys.onPressed: (e) => Navigation.defaultKeyAction(e)
            Keys.onReleased: (e) => Navigation.defaultKeyReleaseAction(e)
        }

        Item {
            Layout.fillHeight: true
        }

        Loader {
            id: loaderProgress

            Layout.fillWidth: true

            active: !root.collapsed && (MainCtx.mediaLibraryAvailable && MainCtx.mediaLibrary.idle === false)
            visible: active

            source: "qrc:///qt/qml/VLC/MediaLibrary/ScanProgressBar.qml"

            onLoaded: {
                if (item.background) {
                    item.background.opacity = 0.6
                    item.background.radius = Qt.binding(() => VLCStyle.radius_small)
                }

                item.leftPadding = Qt.binding(function() { return VLCStyle.margin_small })
                item.rightPadding = Qt.binding(function() { return VLCStyle.margin_small })
            }
        }
    }
}
