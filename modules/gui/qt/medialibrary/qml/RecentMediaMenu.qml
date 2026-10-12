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
import VLC.Widgets as Widgets
import VLC.Style

// "Open Recent" submenu of the main menu: the last played media of the
// media library history.
Widgets.MenuExt {
    id: root

    MLRecentMediaModel {
        id: recentModel
        ml: MediaLib
        limit: 10
    }

    Instantiator {
        model: recentModel

        delegate: Widgets.MenuItemExt {
            required property var model

            text: model.title || model.url || ""
            onTriggered: MediaLib.addAndPlay(model.id)
        }

        onObjectAdded: (index, object) => root.insertItem(index, object)
        onObjectRemoved: (index, object) => root.removeItem(object)
    }

    Widgets.MenuSeparatorExt {
        visible: recentModel.count > 0
        menuPalette: root.menuPalette
    }

    Widgets.MenuItemExt {
        text: recentModel.count > 0 ? qsTr("Clear") : qsTr("No recent media")
        enabled: recentModel.count > 0
        onTriggered: recentModel.clearHistory()
    }
}
