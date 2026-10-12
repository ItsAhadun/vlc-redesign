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
import VLC.Widgets as Widgets
import VLC.PlayerControls
import VLC.Player

// Drag & drop support of the in-place "Customize Player" mode. A single ghost
// follows the pointer above everything (control bar and modal), so items can
// travel between the palette box and the control bar rows.
//
// Draggable items call begin()/move()/end() from their DragHandler; drop
// targets are DropAreas with keys ["vlc-player-control"], `drop.source` is the
// ghost which exposes controlId, sourceModel (ControlListModel, null for the
// palette) and sourceIndex.
Item {
    id: layer

    readonly property bool dragging: ghost.Drag.active

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    function begin(controlId, sourceModel, sourceIndex, scenePos) {
        ghost.controlId = controlId
        ghost.sourceModel = sourceModel
        ghost.sourceIndex = sourceIndex
        move(scenePos)
        ghost.Drag.active = true
    }

    function move(scenePos) {
        const p = layer.mapFromItem(null, scenePos.x, scenePos.y)
        ghost.x = p.x - ghost.width / 2
        ghost.y = p.y - ghost.height / 2
    }

    function end() {
        if (!ghost.Drag.active)
            return
        ghost.Drag.drop()
        ghost.Drag.active = false
        ghost.controlId = -1
    }

    function cancel() {
        ghost.Drag.cancel()
        ghost.Drag.active = false
        ghost.controlId = -1
    }

    Rectangle {
        id: ghost

        property int controlId: -1
        property var sourceModel: null
        property int sourceIndex: -1

        readonly property var _entry: controlId >= 0 ? PlayerControlbarControls.control(controlId) : null

        visible: Drag.active

        width: VLCStyle.iconWrapper_height + VLCStyle.space_8
        height: width
        radius: VLCStyle.radius_small

        color: theme.palette.bgA3Transparent
        border.color: theme.palette.accentMain
        border.width: VLCStyle.dp(1, VLCStyle.scale)

        Drag.keys: ["vlc-player-control"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Drag.source: ghost

        Widgets.IconLabel {
            anchors.centerIn: parent
            text: ghost._entry ? ghost._entry.label : ""
            color: theme.palette.accentMain
            font.pixelSize: VLCStyle.icon_normal
        }
    }
}
