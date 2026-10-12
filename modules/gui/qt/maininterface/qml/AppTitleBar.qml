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
import QtQuick.Window

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.Player

// Unified 40 px window title bar (design/SPEC.md 2.1), shared by the library
// and the player:
//   left: VLC cone, "..." (main menu), optional sidebar toggle, optional
//         divider + folder chip;
//   center: the media title ("VLC Media Player" when idle);
//   right: minimize / maximize / fullscreen / close (client side decorations).
T.ToolBar {
    id: root

    // the ColorContext palette is null until it is inherited from a parent context
    readonly property var _palette: theme.palette ?? VLCStyle.palette

    // Properties

    // player only: sidebar toggle and folder chip
    property bool showSidebarToggle: false
    property bool sidebarExpanded: false
    property string folderName: ""

    property string title: Player.isStarted ? (Player.title || Player.name || "")
                                            : ""

    // set to VLCStyle.darkPalette by the player
    property var barPalette: VLCStyle.palette

    readonly property bool _showCSD: MainCtx.clientSideDecoration
                                     && !(MainCtx.intfMainWindow.visibility === Window.FullScreen)

    property alias menuButton: menuButton

    signal toggleSidebar()
    signal folderClicked()

    // Settings

    implicitHeight: VLCStyle.titleBar_height
    implicitWidth: leftCluster.implicitWidth + windowButtons.implicitWidth

    Accessible.name: qsTr("Title bar")
    AccessibleCompat.id: "titleBar"

    ColorContext {
        id: theme
        colorSet: ColorContext.Window
        palette: root.barPalette
    }

    background: Rectangle {
        color: theme.bg.primary

        //drag and double click the title bar in CSD mode
        Loader {
            anchors.fill: parent
            active: root._showCSD
            sourceComponent: Widgets.CSDTitlebarTapNDrapHandler { }
        }
    }

    contentItem: Item {
        Row {
            id: leftCluster

            x: VLCStyle.space_6
            anchors.verticalCenter: parent.verticalCenter
            height: VLCStyle.iconButton_size

            spacing: VLCStyle.space_6

            Navigation.parentItem: root

            // VLC cone, 24 px in a 38x28 slot (Accent/Logo)
            Item {
                width: VLCStyle.dp(38, VLCStyle.scale)
                height: parent.height

                Widgets.BannerCone {
                    anchors.centerIn: parent
                    color: root._palette.accentLogo
                }
            }

            TitleBarButton {
                id: menuButton

                visible: !MainCtx.hasToolbarMenu
                focus: true

                // TODO(icons): redesign "more" glyph
                text: VLCIcons.ellipsis
                description: qsTr("Menu")
                checked: mainMenu.visible

                Navigation.parentItem: leftCluster
                Navigation.rightItem: sidebarButton

                onClicked: {
                    if (mainMenu.visible)
                        mainMenu.close()
                    else
                        mainMenu.popup(menuButton, 0, menuButton.height + VLCStyle.space_6)
                }
            }

            TitleBarButton {
                id: sidebarButton

                visible: root.showSidebarToggle

                // TODO(icons): redesign expand-sidebar / collapse-sidebar glyphs
                text: VLCIcons.panel_left
                description: root.sidebarExpanded ? qsTr("Collapse sidebar") : qsTr("Expand sidebar")
                color: theme.fg.primary

                Navigation.parentItem: leftCluster
                Navigation.leftItem: menuButton
                Navigation.rightItem: folderButton

                onClicked: root.toggleSidebar()
            }

            // 1 px divider in a 24 px wide slot (with the row spacing)
            Item {
                visible: folderButton.visible
                width: VLCStyle.space_24 - VLCStyle.space_6 * 2
                height: parent.height

                Rectangle {
                    anchors.centerIn: parent
                    width: VLCStyle.border
                    height: VLCStyle.icon_normal * 2 / 3
                    color: root._palette.dividerBright
                }
            }

            T.AbstractButton {
                id: folderButton

                visible: root.folderName.length > 0
                height: parent.height
                padding: 0
                rightPadding: VLCStyle.space_8

                implicitWidth: implicitContentWidth + leftPadding + rightPadding

                focusPolicy: Qt.StrongFocus
                Navigation.parentItem: leftCluster
                Navigation.leftItem: sidebarButton
                Keys.priority: Keys.AfterItem
                Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

                onClicked: root.folderClicked()

                background: Rectangle {
                    radius: VLCStyle.radius_small
                    color: folderButton.hovered ? root._palette.hoverOverlay : "transparent"
                    border.width: folderButton.visualFocus ? VLCStyle.focus_border : 0
                    border.color: theme.visualFocus
                }

                contentItem: Row {
                    spacing: 0

                    Widgets.FolderIcon {
                        width: VLCStyle.iconButton_size
                        height: VLCStyle.iconButton_size
                        color: root._palette.fgA2
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.folderName
                        font.pixelSize: VLCStyle.fontSize_body
                        color: root._palette.fgA2
                    }
                }
            }
        }

        // centered on the window, elided so that it never overlaps the clusters
        Text {
            id: titleLabel

            readonly property real _sideSpace: Math.max(leftCluster.x + leftCluster.width,
                                                        parent.width - windowButtons.x) + VLCStyle.space_16

            anchors.centerIn: parent
            width: Math.max(0, parent.width - _sideSpace * 2)

            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle

            text: root.title.length > 0 ? root.title : qsTr("VLC Media Player")
            font.pixelSize: VLCStyle.fontSize_body
            color: root._palette.fgA2

            Accessible.role: Accessible.TitleBar
        }

        Row {
            id: windowButtons

            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.space_6
            anchors.verticalCenter: parent.verticalCenter

            visible: root._showCSD
            width: visible ? implicitWidth : 0

            spacing: 0

            Repeater {
                id: csdRepeater

                // the platform buttons, with fullscreen inserted before close
                model: {
                    if (!root._showCSD)
                        return []
                    const buttons = []
                    const csdButtons = MainCtx.csdButtonModel.windowCSDButtons
                    for (let i = 0; i < csdButtons.length; ++i) {
                        if (csdButtons[i].type === CSDButton.Close)
                            buttons.push({ "fullscreen": true })
                        buttons.push(csdButtons[i])
                    }
                    return buttons
                }

                delegate: WindowButton {
                    id: csdButton

                    required property var modelData

                    readonly property bool isFullscreenButton: modelData.fullscreen === true

                    showHovered: !isFullscreenButton && modelData.showHovered
                    externalPressed: !isFullscreenButton && modelData.externalPressed

                    iconTxt: {
                        if (isFullscreenButton)
                            return VLCIcons.fullscreen
                        switch (modelData.type) {
                        case CSDButton.Minimize:
                            return VLCIcons.window_minimize
                        case CSDButton.MaximizeRestore:
                            return (MainCtx.intfMainWindow.visibility === Window.Maximized)
                                    ? VLCIcons.window_restore
                                    : VLCIcons.window_maximize
                        case CSDButton.Close:
                            return VLCIcons.window_close
                        }
                        return ""
                    }

                    description: {
                        if (isFullscreenButton)
                            return qsTr("Fullscreen")
                        switch (modelData.type) {
                        case CSDButton.Minimize:
                            return qsTr("Minimize")
                        case CSDButton.MaximizeRestore:
                            return (MainCtx.intfMainWindow.visibility === Window.Maximized)
                                    ? qsTr("Restore") : qsTr("Maximize")
                        case CSDButton.Close:
                            return qsTr("Close")
                        }
                        return ""
                    }

                    onClicked: {
                        if (isFullscreenButton)
                            MainCtx.toggleInterfaceFullScreen()
                        else
                            modelData.click()
                    }

                    // keep the platform informed of the button geometry (Windows snap layouts)
                    onXChanged: Qt.callLater(updateRect)
                    onWidthChanged: Qt.callLater(updateRect)
                    onHeightChanged: Qt.callLater(updateRect)

                    Connections {
                        target: VLCStyle
                        function onAppWidthChanged() { Qt.callLater(csdButton.updateRect) }
                        function onAppHeightChanged() { Qt.callLater(csdButton.updateRect) }
                    }

                    function updateRect() {
                        if (isFullscreenButton)
                            return
                        const point = mapToItem(null, 0, 0)
                        modelData.rect = Qt.rect(point.x, point.y, width, height)
                    }
                }
            }
        }
    }

    MainMenu {
        id: mainMenu
        menuPalette: theme.palette
    }

    // Icon button of the title bar: 28x28, 24 px glyph (Icon Wrapper hover)
    component TitleBarButton: Widgets.IconToolButton {
        width: VLCStyle.iconButton_size
        height: VLCStyle.iconButton_size
        font.pixelSize: VLCStyle.icon_normal
        radius: VLCStyle.radius_small
    }

    // 36x24 window button
    component WindowButton: T.Button {
        id: windowButton

        property string iconTxt
        property string description
        property bool showHovered: false
        property bool externalPressed: false

        readonly property bool _paintHovered: hovered || showHovered

        width: VLCStyle.windowButton_width
        height: VLCStyle.windowButton_height
        padding: 0

        focusPolicy: Qt.NoFocus

        Accessible.name: description

        background: Rectangle {
            radius: VLCStyle.radius_small
            color: {
                if (windowButton.pressed || (windowButton.externalPressed && windowButton._paintHovered))
                    return root._palette.bgA1
                if (windowButton._paintHovered)
                    return root._palette.hoverOverlay
                return "transparent"
            }
        }

        contentItem: Widgets.IconLabel {
            text: windowButton.iconTxt
            // TODO(icons): redesign window glyphs (thin 16 px)
            font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
            color: windowButton._paintHovered ? (root._palette.isDark ? root._palette.fg1 : root._palette.fgA1) : root._palette.fgA2
        }
    }
}
