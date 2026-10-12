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

import VLC.MainInterface
import VLC.Style

// Generic single-list popup over a model exposing `display` and `checked`
// roles (track lists, VLCVarChoiceModel, chapters...). `select(index)` is
// called on click.
PlayerPopup {
    id: root

    property string title: ""
    property var model: null
    property var select: function(index) {}

    contentItem: PopupList {
        id: list

        PopupSection {
            width: list.width
            separator: false
            visible: root.title !== ""
            text: root.title
        }

        Repeater {
            model: root.model

            delegate: PopupOption {
                required property var model
                required property int index

                width: list.width
                text: model.display ?? model.name ?? ""
                checked: !!model.checked
                onClicked: root.select(index)
            }
        }
    }
}
