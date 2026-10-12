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

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

// Library page header row (design/SPEC.md 2.1):
//   back / forward, breadcrumb (last segment bold) ...
//   ... "N items", sort, view mode, search field, "+", "..."
// followed by a Divider/Dim line.
//
// breadcrumbModel: [{ text, path, siblings: [{ text, path }] }]; a segment with
// siblings opens a menu to switch between them.
// moreActions: [{ text, action: function(), visible: bool }] for the "..." menu.
T.ToolBar {
    id: root

    // the ColorContext palette is null until it is inherited from a parent context
    readonly property var _palette: theme.palette ?? VLCStyle.palette

    // Properties

    property var breadcrumbModel: []

    // -1 hides the count
    property int itemCount: -1

    property SortCtx sort: null
    property SearchCtx search: null
    property var sortMenu: null

    property bool hasGridListMode: false

    // function() or null to hide the "+" button
    property var addAction: null
    property string addDescription: qsTr("Add")

    property var moreActions: []

    // back / forward history buttons
    property bool showNavigationButtons: true

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    // Settings

    position: T.ToolBar.Header

    // header row center sits 37 px below the title bar, the content starts
    // 20 px after the divider
    topPadding: VLCStyle.dp(21, VLCStyle.scale)
    bottomPadding: VLCStyle.space_20

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Page header")

    background: Rectangle {
        color: root._palette.bgB1
    }

    contentItem: Column {
        spacing: VLCStyle.dp(17, VLCStyle.scale)

        RowLayout {
            id: row

            width: parent.width
            height: VLCStyle.searchField_height

            spacing: 0

            HeaderButton {
                id: backButton

                visible: root.showNavigationButtons

                // TODO(icons): redesign "arrow-left" glyph
                text: VLCIcons.back
                description: qsTr("Previous")
                enabled: !History.previousEmpty

                Navigation.parentItem: root
                Navigation.rightItem: forwardButton

                onClicked: History.previous(Qt.MouseFocusReason)
            }

            HeaderButton {
                id: forwardButton

                Layout.leftMargin: VLCStyle.space_6

                visible: root.showNavigationButtons

                // TODO(icons): redesign "arrow-right" glyph
                text: VLCIcons.back
                contentItem.rotation: 180
                description: qsTr("Next")
                enabled: !History.nextEmpty

                Navigation.parentItem: root
                Navigation.leftItem: backButton
                Navigation.rightItem: sortButton.visible ? sortButton : viewButton

                onClicked: History.next(Qt.MouseFocusReason)
            }

            // Breadcrumb
            // NOTE: the breadcrumb is mouse only, keyboard users have back/forward
            Item {
                id: breadcrumb

                Layout.leftMargin: root.showNavigationButtons ? VLCStyle.space_8 : 0
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: row.height

                clip: crumbRow.width > width

                Row {
                    id: crumbRow
                    height: parent.height
                    spacing: 0

                    Repeater {
                        model: root.breadcrumbModel

                        delegate: Row {
                            id: crumb

                            required property var modelData
                            required property int index

                            readonly property bool isLast: index === root.breadcrumbModel.length - 1

                            height: breadcrumb.height
                            spacing: 0

                            // small right pointing triangle separator, 24 px slot
                            Item {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: crumb.index > 0
                                width: VLCStyle.space_24
                                height: VLCStyle.space_8

                                Item {
                                    anchors.centerIn: parent
                                    width: VLCStyle.dp(4, VLCStyle.scale)
                                    height: VLCStyle.space_8
                                    clip: true

                                    Rectangle {
                                        width: parent.height * Math.SQRT1_2
                                        height: width
                                        x: -width / 2
                                        y: (parent.height - height) / 2
                                        rotation: 45
                                        antialiasing: true
                                        color: root._palette.fgA3
                                    }
                                }
                            }

                            T.AbstractButton {
                                id: crumbButton

                                anchors.verticalCenter: parent.verticalCenter
                                height: VLCStyle.iconWrapper_height
                                implicitWidth: implicitContentWidth + leftPadding + rightPadding

                                focusPolicy: Qt.NoFocus
                                padding: 0
                                leftPadding: VLCStyle.space_2
                                rightPadding: VLCStyle.space_2

                                text: crumb.modelData.text

                                readonly property bool hasSiblings: (crumb.modelData.siblings?.length ?? 0) > 1

                                enabled: hasSiblings || !crumb.isLast

                                Accessible.role: Accessible.Link
                                Accessible.name: text

                                onClicked: {
                                    if (hasSiblings) {
                                        siblingsMenu.siblings = crumb.modelData.siblings
                                        siblingsMenu.current = crumb.modelData.text
                                        siblingsMenu.popup(crumbButton, 0, crumbButton.height)
                                    } else {
                                        History.push(crumb.modelData.path, Qt.MouseFocusReason)
                                    }
                                }

                                background: Rectangle {
                                    radius: VLCStyle.radius_small
                                    color: "transparent"
                                    border.width: crumbButton.visualFocus ? VLCStyle.focus_border : 0
                                    border.color: theme.visualFocus
                                }

                                contentItem: Text {
                                    text: crumbButton.text
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: VLCStyle.fontSize_body
                                    font.weight: crumb.isLast ? VLCStyle.fontWeight_semiBold : VLCStyle.fontWeight_regular
                                    font.underline: crumbButton.hovered && crumbButton.enabled
                                    color: crumb.isLast ? (root._palette.isDark ? root._palette.fg2 : root._palette.fgA1)
                                                        : (crumbButton.hovered ? (root._palette.isDark ? root._palette.fg1 : root._palette.fgA1) : root._palette.fgA2)
                                }
                            }
                        }
                    }
                }
            }

            Text {
                id: countLabel

                Layout.leftMargin: VLCStyle.space_16

                visible: root.itemCount >= 0
                text: (root.itemCount === 1) ? qsTr("1 item") : qsTr("%1 items").arg(root.itemCount)
                font.pixelSize: VLCStyle.fontSize_body
                color: root._palette.fgA3
            }

            Widgets.SortControl {
                id: sortButton

                Layout.leftMargin: VLCStyle.space_14
                Layout.preferredWidth: VLCStyle.iconWrapper_width
                Layout.preferredHeight: VLCStyle.iconWrapper_height

                visible: !!root.sort && root.sort.available

                radius: VLCStyle.radius_small
                color: checked ? root._palette.accentMain : root._palette.fgA2

                model: root.sort?.model ?? []
                menu: root.sortMenu

                sortKey: root.sort?.criteria
                sortOrder: root.sort?.order

                onSortSelected: (key) => { root.sort.criteria = key }
                onSortOrderSelected: (type) => { root.sort.order = type }

                Navigation.parentItem: root
                Navigation.leftItem: forwardButton
                Navigation.rightItem: viewButton
            }

            HeaderButton {
                id: viewButton

                Layout.leftMargin: VLCStyle.space_14

                visible: root.hasGridListMode

                // TODO(icons): redesign "grid" / "list" glyphs
                text: MainCtx.gridView ? VLCIcons.grid : VLCIcons.list
                description: qsTr("View Options")
                checked: viewMenu.visible

                Navigation.parentItem: root
                Navigation.leftItem: sortButton
                Navigation.rightItem: searchField

                onClicked: {
                    if (viewMenu.visible)
                        viewMenu.close()
                    else
                        viewMenu.popup(viewButton, 0, viewButton.height + VLCStyle.margin_xxsmall)
                }
            }

            Widgets.SearchField {
                id: searchField

                Layout.leftMargin: VLCStyle.space_16
                Layout.preferredWidth: Math.min(implicitWidth, Math.max(VLCStyle.dp(120, VLCStyle.scale),
                                                                        root.availableWidth / 5))
                Layout.preferredHeight: VLCStyle.searchField_height

                visible: !!root.search && root.search.available

                Navigation.parentItem: root
                Navigation.leftItem: viewButton
                Navigation.rightItem: addButton

                Binding {
                    target: root.search
                    when: !!root.search
                    property: "pattern"
                    value: searchField.searchPattern
                }

                Connections {
                    target: root.search
                    function onAskShow() {
                        searchField.expandAndFocus()
                    }
                }
            }

            HeaderButton {
                id: addButton

                Layout.leftMargin: VLCStyle.space_16

                visible: typeof root.addAction === "function"

                // TODO(icons): redesign "add" glyph
                text: VLCIcons.add
                description: root.addDescription

                Navigation.parentItem: root
                Navigation.leftItem: searchField
                Navigation.rightItem: moreButton

                onClicked: root.addAction()
            }

            HeaderButton {
                id: moreButton

                Layout.leftMargin: VLCStyle.space_6

                visible: root.moreActions.some((a) => a.visible !== false)

                // TODO(icons): redesign "more" glyph
                text: VLCIcons.ellipsis
                description: qsTr("More")
                checked: moreMenu.visible

                Navigation.parentItem: root
                Navigation.leftItem: addButton

                onClicked: {
                    if (moreMenu.visible)
                        moreMenu.close()
                    else
                        moreMenu.popup(moreButton, moreButton.width - moreMenu.implicitWidth,
                                       moreButton.height + VLCStyle.margin_xxsmall)
                }
            }

        }

        Rectangle {
            width: parent.width
            height: VLCStyle.border
            color: root._palette.dividerDim
        }
    }

    // "View Options" (design/SPEC.md 3.9, 858:3290)
    Widgets.MenuExt {
        id: viewMenu

        menuPalette: theme.palette

        Widgets.MenuItemExt {
            text: qsTr("Grid")
            iconText: VLCIcons.grid
            selected: MainCtx.gridView
            onTriggered: MainCtx.gridView = true
        }

        Widgets.MenuItemExt {
            text: qsTr("List")
            iconText: VLCIcons.list
            selected: !MainCtx.gridView
            onTriggered: MainCtx.gridView = false
        }
    }

    Widgets.MenuExt {
        id: moreMenu

        menuPalette: theme.palette

        Instantiator {
            model: root.moreActions

            delegate: Widgets.MenuItemExt {
                required property var modelData

                text: modelData.text
                iconText: modelData.iconText ?? ""
                visible: modelData.visible !== false
                onTriggered: modelData.action()
            }

            onObjectAdded: (index, object) => moreMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => moreMenu.removeItem(object)
        }
    }

    Widgets.MenuExt {
        id: siblingsMenu

        property var siblings: []
        property string current: ""

        menuPalette: theme.palette

        Instantiator {
            model: siblingsMenu.siblings

            delegate: Widgets.MenuItemExt {
                required property var modelData

                text: modelData.text
                selected: modelData.text === siblingsMenu.current
                onTriggered: History.push(modelData.path, Qt.MouseFocusReason)
            }

            onObjectAdded: (index, object) => siblingsMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => siblingsMenu.removeItem(object)
        }
    }

    // 30x32 Icon Wrapper button
    component HeaderButton: Widgets.IconToolButton {
        Layout.preferredWidth: VLCStyle.iconWrapper_width
        Layout.preferredHeight: VLCStyle.iconWrapper_height

        font.pixelSize: VLCStyle.icon_normal
        radius: VLCStyle.radius_small

        color: checked ? root._palette.accentMain
                       : (enabled ? root._palette.fgA2 : root._palette.fgA4)
    }
}
