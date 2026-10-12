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


import VLC.MainInterface
import VLC.Style
import VLC.Menus
import VLC.Widgets as Widgets

// Sort button + "Sorting Options" popup (design/SPEC.md 3.9, 856:2215): the
// sort keys (current one in the accent color), the order, and the extra
// options of a custom `menu` (video grouping, album sections).
// An accent dot on the button tells that a non default sorting is applied.
Widgets.IconToolButton {
    id: root

    // Properties

    property var model: []

    property bool popupAbove: false

    property real listWidth: VLCStyle.widthSortBox

    // NOTE: This allows us provide extra options (SortMenuVideo, SortMenuAlbums)
    property SortMenu menu

    // properties that should be handled by parent
    // if they are not updated, tick mark and order mark will not be shown
    property var sortKey: undefined
    property var sortOrder: undefined

    // whether the current sorting differs from the default one
    readonly property bool nonDefault: {
        if (!root.model || root.model.length === 0)
            return false
        const keyIsDefault = (root.sortKey === undefined || root.sortKey === ""
                              || root.sortKey === root.model[0].criteria
                              || !root.model.some((entry) => entry.criteria === root.sortKey))
        // the order only matters for an explicitly chosen key
        return !keyIsDefault || (root.sortKey !== undefined && root.sortKey !== ""
                                 && root.sortOrder === Qt.DescendingOrder)
    }

    // Signals

    // sortSelected is triggered with new sorting key when a different sorting key is selected
    // sortOrderSelected is triggered with Qt.AscendingOrder when different sorting key is selected
    // sortOrderSelected is triggered with Qt.AscendingOrder or Qt.DescendingOrder when the order is selected
    signal sortSelected(var key)
    signal sortOrderSelected(int type)


    font.pixelSize: VLCStyle.icon_normal

    focus: true

    description: qsTr("Sort")

    // TODO(icons): redesign "sort" glyph
    text: VLCIcons.topbar_sort

    checked: sortPopup.visible

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)


    // Events

    onClicked: root.show()
    onVisibleChanged: if (!visible) sortPopup.close()
    onEnabledChanged: if (!enabled) sortPopup.close()

    // Functions

    function show() {
        if (sortPopup.visible) {
            sortPopup.close()
            return
        }

        if (root.popupAbove)
            sortPopup.popup(root, 0, - sortPopup.implicitHeight - VLCStyle.margin_xxsmall)
        else
            sortPopup.popup(root, 0, root.height + VLCStyle.margin_xxsmall)
    }

    // Children

    // non default sorting indicator
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: VLCStyle.dp(3, VLCStyle.scale)
        anchors.topMargin: VLCStyle.dp(3, VLCStyle.scale)

        width: VLCStyle.dp(4, VLCStyle.scale)
        height: width
        radius: width / 2

        visible: root.nonDefault
        color: (root.colorContext.palette ?? VLCStyle.palette).accentMain
    }

    Widgets.MenuExt {
        id: sortPopup

        menuPalette: root.colorContext.palette

        Instantiator {
            model: root.model

            delegate: Widgets.MenuItemExt {
                required property var modelData

                text: modelData.text
                selected: (modelData.criteria === root.sortKey)

                onTriggered: {
                    if (root.sortKey !== modelData.criteria) {
                        root.sortSelected(modelData.criteria)
                        root.sortOrderSelected(Qt.AscendingOrder)
                    }
                }
            }

            onObjectAdded: (index, object) => sortPopup.insertItem(index, object)
            onObjectRemoved: (index, object) => sortPopup.removeItem(object)
        }

        Widgets.MenuSeparatorExt { menuPalette: sortPopup.menuPalette }

        Widgets.MenuItemExt {
            text: qsTr("Ascending")
            selected: root.sortOrder === Qt.AscendingOrder
            onTriggered: root.sortOrderSelected(Qt.AscendingOrder)
        }

        Widgets.MenuItemExt {
            text: qsTr("Descending")
            selected: root.sortOrder === Qt.DescendingOrder
            onTriggered: root.sortOrderSelected(Qt.DescendingOrder)
        }

        // video grouping (SortMenuVideo)
        Widgets.MenuSeparatorExt {
            visible: root.menu instanceof SortMenuVideo
            height: visible ? implicitHeight : 0
            menuPalette: sortPopup.menuPalette
        }

        Widgets.MenuItemExt {
            visible: root.menu instanceof SortMenuVideo
            text: qsTr("Do not group videos")
            selected: MainCtx.grouping === MainCtx.GROUPING_NONE
            onTriggered: MainCtx.grouping = MainCtx.GROUPING_NONE
        }

        Widgets.MenuItemExt {
            visible: root.menu instanceof SortMenuVideo
            text: qsTr("Group by name")
            selected: MainCtx.grouping === MainCtx.GROUPING_NAME
            onTriggered: MainCtx.grouping = MainCtx.GROUPING_NAME
        }

        Widgets.MenuItemExt {
            visible: root.menu instanceof SortMenuVideo
            text: qsTr("Group by folder")
            selected: MainCtx.grouping === MainCtx.GROUPING_FOLDER
            onTriggered: MainCtx.grouping = MainCtx.GROUPING_FOLDER
        }

        // album sections (SortMenuAlbums)
        Widgets.MenuSeparatorExt {
            visible: (root.menu instanceof SortMenuAlbums) && root.menu.sectionsVisible
            height: visible ? implicitHeight : 0
            menuPalette: sortPopup.menuPalette
        }

        Widgets.MenuItemExt {
            visible: (root.menu instanceof SortMenuAlbums) && root.menu.sectionsVisible
            text: qsTr("Album sections")
            selected: MainCtx.albumSections
            onTriggered: MainCtx.albumSections = !MainCtx.albumSections
        }
    }
}
