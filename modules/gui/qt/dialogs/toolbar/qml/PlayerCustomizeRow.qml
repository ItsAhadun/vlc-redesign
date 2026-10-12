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

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.PlayerControls
import VLC.Player

// One editable zone (left / center / right) of the control bar in
// "Customize Player" mode: every control is drawn (paint only) inside a dashed
// outline and can be dragged to re-order it, to another zone, or into the
// palette box to remove it. Items dropped here from the palette are inserted.
Item {
    id: root

    // ControlListModel edited by this row
    property var listModel: null

    property real spacing: VLCStyle.space_6

    // the PlayerCustomizeDragLayer of the player page
    property Item dragLayer: null

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    // index where a drop would insert, -1 when no drag is over the row
    property int _dropIndex: -1

    implicitWidth: Math.max(row.implicitWidth, VLCStyle.iconWrapper_width * 2)
    implicitHeight: VLCStyle.controlBar_height

    function _indexAt(x) {
        for (let i = 0; i < repeater.count; ++i) {
            const it = repeater.itemAt(i)
            if (it && x < it.x + it.width / 2)
                return i
        }
        return repeater.count
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter

        spacing: root.spacing

        Repeater {
            id: repeater

            model: root.listModel

            delegate: Item {
                id: cell

                required property int index
                required property int id

                readonly property real _pad: VLCStyle.space_2

                implicitWidth: Math.max(loader.implicitWidth, VLCStyle.icon_normal) + _pad * 2
                implicitHeight: Math.max(loader.implicitHeight, VLCStyle.icon_normal) + _pad * 2
                width: implicitWidth
                height: implicitHeight

                opacity: (dragHandler.active) ? 0.4 : 1.0

                Loader {
                    id: loader

                    anchors.centerIn: parent

                    source: PlayerControlbarControls.control(cell.id).source

                    onLoaded: {
                        item.paintOnly = true
                        item.enabled = false
                        if ((item.description !== undefined) && (item.horizontalPadding !== undefined)) {
                            item.horizontalPadding = (VLCStyle.iconWrapper_width - VLCStyle.icon_normal) / 2
                            item.verticalPadding = (VLCStyle.iconWrapper_height - VLCStyle.icon_normal) / 2
                        }
                    }
                }

                DashedOutline {
                    anchors.fill: parent
                    color: dragHandler.active ? theme.palette.accentMain : theme.palette.fgA3
                }

                // insertion marker
                Rectangle {
                    visible: root._dropIndex === cell.index
                    x: -root.spacing / 2 - width / 2
                    width: VLCStyle.dp(2, VLCStyle.scale)
                    height: parent.height
                    color: theme.palette.accentMain
                }

                HoverHandler {
                    cursorShape: Qt.OpenHandCursor
                }

                DragHandler {
                    id: dragHandler

                    target: null
                    enabled: !!root.dragLayer

                    onActiveChanged: {
                        if (active)
                            root.dragLayer.begin(cell.id, root.listModel, cell.index, centroid.scenePosition)
                        else
                            root.dragLayer.end()
                    }

                    onCentroidChanged: {
                        if (active)
                            root.dragLayer.move(centroid.scenePosition)
                    }
                }
            }
        }
    }

    // insertion marker after the last item / in an empty row
    Rectangle {
        visible: root._dropIndex >= 0 && root._dropIndex === repeater.count
        x: repeater.count > 0 ? row.x + row.width + root.spacing / 2 - width / 2 : (root.width - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: VLCStyle.dp(2, VLCStyle.scale)
        height: VLCStyle.iconWrapper_height
        color: theme.palette.accentMain
    }

    // empty row: keep a visible drop slot
    DashedOutline {
        visible: repeater.count === 0
        anchors.centerIn: parent
        width: VLCStyle.iconWrapper_width * 2
        height: VLCStyle.iconWrapper_height
        color: theme.palette.fgA4
    }

    DropArea {
        anchors.fill: parent
        anchors.margins: -VLCStyle.space_6

        keys: ["vlc-player-control"]

        onPositionChanged: (drag) => { root._dropIndex = root._indexAt(drag.x - VLCStyle.space_6) }
        onEntered: (drag) => { root._dropIndex = root._indexAt(drag.x - VLCStyle.space_6) }
        onExited: root._dropIndex = -1

        onDropped: (drop) => {
            const src = drop.source
            let to = root._indexAt(drop.x - VLCStyle.space_6)
            root._dropIndex = -1

            if (!root.listModel || !src || src.controlId < 0)
                return

            if (src.sourceModel === root.listModel) {
                // re-order inside the row
                let from = src.sourceIndex
                if (to > from)
                    to -= 1
                if (to !== from)
                    root.listModel.move(from, to)
            } else {
                if (src.sourceModel)
                    src.sourceModel.remove(src.sourceIndex)
                root.listModel.insert(to, { "id": src.controlId })
            }
            drop.accept(Qt.MoveAction)
        }
    }
}
