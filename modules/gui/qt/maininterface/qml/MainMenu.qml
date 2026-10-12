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
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs
import VLC.Util

// Main menu, opened from the title bar "..." button
// (design/SPEC.md 3.9, "menu" 6062:13354; labels and shortcuts verbatim).
// The shortcuts are only displayed here, they are handled by the global
// shortcuts (menus/qml/GlobalShortcuts.qml) and the hotkeys module.
Widgets.MenuExt {
    id: root

    rowWidth: VLCStyle.dp(367, VLCStyle.scale)

    // TODO(icons): file, folder, link, disc, capture-device, convert, recent,
    //              profile, hotkeys, paint, settings and info redesign glyphs
    Widgets.MenuItemExt {
        text: qsTr("Open File(s)")
        iconText: VLCIcons.ic_fluent_document_add_24_regular
        shortcutText: qsTr("Ctrl + O")
        onTriggered: DialogsProvider.simpleOpenDialog()
    }

    Widgets.MenuItemExt {
        text: qsTr("Open Folder")
        iconText: VLCIcons.medialibrary_add
        shortcutText: qsTr("Ctrl + F")
        onTriggered: DialogsProvider.PLOpenDir()
    }

    Widgets.MenuItemExt {
        text: qsTr("Open Network Stream")
        iconText: VLCIcons.stream
        shortcutText: qsTr("Ctrl + N")
        onTriggered: DialogsProvider.openNetDialog()
    }

    Widgets.MenuItemExt {
        text: qsTr("Open Disc")
        iconText: VLCIcons.eject
        shortcutText: qsTr("Ctrl + D")
        onTriggered: DialogsProvider.openDiscDialog()
    }

    Widgets.MenuItemExt {
        text: qsTr("Open Capture Device")
        iconText: VLCIcons.tv
        shortcutText: qsTr("Ctrl + C")
        onTriggered: DialogsProvider.openCaptureDialog()
    }

    Widgets.MenuItemExt {
        text: qsTr("Convert")
        iconText: VLCIcons.ic_fluent_arrow_sync_24_regular
        shortcutText: qsTr("Ctrl + R")
        onTriggered: DialogsProvider.openAndTranscodingDialogs()
    }

    // "Open Recent" submenu, needs the media library (see Component.onCompleted)
    Widgets.MenuItemExt {
        id: recentPlaceholder

        text: qsTr("Open Recent")
        iconText: VLCIcons.history
        enabled: false
        visible: !MainCtx.mediaLibraryAvailable
    }

    Widgets.MenuSeparatorExt { menuPalette: root.menuPalette }

    Widgets.MenuExt {
        id: profileMenu

        title: qsTr("Profile (%1)").arg(MainCtx.controlbarProfileModel.currentModel?.name ?? "")
        iconText: VLCIcons.profile_new
        menuPalette: root.menuPalette

        Instantiator {
            model: MainCtx.controlbarProfileModel

            delegate: Widgets.MenuItemExt {
                required property int index
                required property string name

                text: name
                checkable: true
                checked: (MainCtx.controlbarProfileModel.selectedProfile === index)
                onTriggered: MainCtx.controlbarProfileModel.selectedProfile = index
            }

            onObjectAdded: (index, object) => profileMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => profileMenu.removeItem(object)
        }
    }

    // TODO: open the redesigned Keyboard Shortcuts dialog (settings engineer);
    //       the hotkeys editor currently lives in the preferences
    Widgets.MenuItemExt {
        text: qsTr("Keyboard Shortcuts")
        iconText: VLCIcons.space
        onTriggered: DialogsProvider.prefsDialog()
    }

    Widgets.MenuItemExt {
        text: qsTr("Customize Player")
        iconText: VLCIcons.ic_fluent_text_change_case_24_regular
        onTriggered: DialogsProvider.showToolbarEditorDialog()
    }

    Widgets.MenuItemExt {
        text: qsTr("Settings")
        iconText: VLCIcons.settings
        shortcutText: qsTr("Ctrl + P")
        onTriggered: DialogsProvider.prefsDialog()
    }

    Widgets.MenuItemExt {
        text: qsTr("About VLC")
        iconText: VLCIcons.info
        shortcutText: qsTr("Shift + F1")
        onTriggered: DialogsProvider.aboutDialog()
    }

    Component.onCompleted: {
        // the recent media submenu lives in the media library module, which
        // may not be available
        if (!MainCtx.mediaLibraryAvailable)
            return

        const component = Qt.createComponent("qrc:///qt/qml/VLC/MediaLibrary/RecentMediaMenu.qml")
        if (component.status !== Component.Ready) {
            console.warn("unable to load the recent media menu:", component.errorString())
            return
        }

        const menu = component.createObject(root, {
            "title": qsTr("Open Recent"),
            "iconText": VLCIcons.history
        })
        menu.menuPalette = Qt.binding(() => root.menuPalette)
        // after "Convert"
        root.insertMenu(6, menu)
    }
}
