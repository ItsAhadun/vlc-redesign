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
import QtQuick.Window
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Dialogs

// Settings window (design/SPEC.md 2.3): a frameless 1048x865 top-level
// window with a header (search, page title, close), the category sidebar and
// the page content. Opened by DialogsProvider.prefsDialog() (menu, Ctrl+P,
// toolbar/navigation buttons); "All VLC preferences" opens the classic
// preferences dialog.
Window {
    id: window

    property string pageId: "general"

    readonly property var pal: VLCStyle.palette

    transientParent: MainCtx.intfMainWindow
    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: Qt.NonModal
    title: qsTr("Settings")

    width: VLCStyle.settingsWindow_width
    height: Math.min(VLCStyle.settingsWindow_height, Screen.desktopAvailableHeight - VLCStyle.space_20)
    minimumWidth: width
    maximumWidth: width
    minimumHeight: Math.min(height, VLCStyle.dp(480, VLCStyle.scale))

    color: pal.bgB1

    function centerOnParent() {
        const p = window.transientParent
        if (!p)
            return
        window.x = p.x + (p.width - window.width) / 2
        window.y = Math.max(Screen.virtualY, p.y + (p.height - window.height) / 2)
    }

    onClosing: {
        SettingsBackend.save()
        DialogsProvider.settingsWindowVisible = false
    }

    Component.onCompleted: {
        if (MainCtx.createWindowWithoutRedirectionSurface) { // Win32
            const ret = MainCtx.createWindowWithoutRedirectionSurface(this)
            if (!ret)
                console.debug("MainCtx::createWindowWithoutRedirectionSurface(): returned false for window", this)
        }
        centerOnParent()
        show()
        raise()
        requestActivate()
        sidebar.focusCurrent()
    }

    SettingsPages {
        id: settingsPages
    }

    FocusScope {
        id: content

        anchors.fill: parent
        focus: true

        readonly property ColorContext colorContext: ColorContext {
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        Keys.onEscapePressed: window.close()

        Shortcut {
            sequences: [StandardKey.Find]
            context: Qt.WindowShortcut
            onActivated: searchField.forceActiveFocus(Qt.ShortcutFocusReason)
        }

        // -- header -----------------------------------------------------------
        Rectangle {
            id: header

            width: parent.width
            height: VLCStyle.settingsHeader_height
            color: window.pal.bgB2

            DragHandler {
                target: null
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                onActiveChanged: if (active) window.startSystemMove()
            }

            SettingsSearchField {
                id: searchField

                x: VLCStyle.space_8
                y: VLCStyle.space_8
                KeyNavigation.down: sidebar
                KeyNavigation.tab: sidebar
            }

            Text {
                x: VLCStyle.dp(240, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                width: closeButton.x - x - VLCStyle.space_20
                text: searchField.text.trim() !== "" ? qsTr("Search Results")
                                                     : (settingsPages.page(window.pageId)?.title ?? "")
                font.pixelSize: VLCStyle.fontSize_title
                color: window.pal.fgA1
                elide: Text.ElideRight
                Accessible.role: Accessible.Heading
                Accessible.name: text
            }

            T.AbstractButton {
                id: closeButton

                x: parent.width - width - VLCStyle.dp(14, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(32, VLCStyle.scale)
                height: width
                focusPolicy: Qt.StrongFocus

                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Close")

                Keys.onReturnPressed: window.close()
                Keys.onSpacePressed: window.close()
                onClicked: window.close()

                background: Rectangle {
                    radius: VLCStyle.radius_small
                    color: closeButton.pressed ? Qt.alpha(window.pal.hoverOverlay, 0.1)
                         : closeButton.hovered ? window.pal.hoverOverlay : "transparent"
                    border.width: closeButton.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
                    border.color: window.pal.accentMain
                }

                contentItem: Widgets.IconLabel {
                    text: VLCIcons.close
                    font.pixelSize: VLCStyle.icon_normal
                    color: closeButton.hovered ? (window.pal.isDark ? window.pal.fg2 : window.pal.fgB1) : window.pal.fgA2
                }
            }
        }

        // -- sidebar ----------------------------------------------------------
        Rectangle {
            id: sidebarCard

            x: VLCStyle.space_8
            y: header.height + VLCStyle.space_8
            width: VLCStyle.settingsSidebar_width - 2 * VLCStyle.space_8
            height: parent.height - y - VLCStyle.space_8
            radius: VLCStyle.radius_large
            color: window.pal.bgA4

            Flickable {
                anchors.fill: parent
                anchors.margins: VLCStyle.space_6
                clip: true
                contentHeight: sidebar.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                FocusScope {
                    id: sidebar

                    width: parent.width
                    implicitHeight: sidebarColumn.implicitHeight

                    Accessible.role: Accessible.PageTabList
                    Accessible.name: qsTr("Settings categories")

                    function focusCurrent() {
                        for (const b of sidebarColumn.buttons())
                            if (b.pageId === window.pageId)
                                b.forceActiveFocus(Qt.OtherFocusReason)
                    }

                    function move(delta) {
                        const list = sidebarColumn.buttons()
                        const i = list.findIndex((b) => b.pageId === window.pageId)
                        const j = Math.max(0, Math.min(list.length - 1, i + delta))
                        window.pageId = list[j].pageId
                        list[j].forceActiveFocus(Qt.TabFocusReason)
                    }

                    Column {
                        id: sidebarColumn

                        width: parent.width
                        spacing: VLCStyle.space_8

                        function buttons() {
                            const out = []
                            for (const g of children)
                                if (g.categoryButtons)
                                    out.push(...g.categoryButtons())
                            return out
                        }

                        Repeater {
                            model: settingsPages.groups

                            delegate: Column {
                                id: group

                                required property var modelData
                                width: sidebarColumn.width
                                spacing: VLCStyle.space_8

                                function categoryButtons() {
                                    const out = []
                                    for (const c of children)
                                        if (c.pageId !== undefined)
                                            out.push(c)
                                    return out
                                }

                                Text {
                                    width: parent.width
                                    height: VLCStyle.dp(33, VLCStyle.scale)
                                    leftPadding: VLCStyle.space_10
                                    verticalAlignment: Text.AlignVCenter
                                    text: group.modelData.name
                                    font.pixelSize: VLCStyle.fontSize_body
                                    color: window.pal.fgA3
                                    Accessible.ignored: true
                                }

                                Repeater {
                                    model: group.modelData.pages

                                    delegate: SettingsCategoryButton {
                                        required property string modelData
                                        readonly property string pageId: modelData
                                        readonly property var pageData: settingsPages.page(modelData)

                                        width: group.width
                                        text: pageData.name
                                        iconName: pageData.icon
                                        selected: window.pageId === pageId && searchField.text.trim() === ""

                                        onClicked: {
                                            searchField.text = ""
                                            window.pageId = pageId
                                        }
                                        Keys.onUpPressed: sidebar.move(-1)
                                        Keys.onDownPressed: sidebar.move(1)
                                        Keys.onRightPressed: pageView.forceActiveFocus(Qt.TabFocusReason)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // -- content ----------------------------------------------------------
        SettingsPageView {
            id: pageView

            x: VLCStyle.settingsSidebar_width
            y: header.height
            width: parent.width - x
            height: parent.height - y

            pages: settingsPages
            pageId: window.pageId
            query: searchField.text

            onPageRequested: (id) => {
                searchField.text = ""
                window.pageId = id
            }
        }
    }
}
