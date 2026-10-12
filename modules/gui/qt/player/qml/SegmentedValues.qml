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
import VLC.Style

// "Values" component (design/SPEC.md 3.6): segmented control, track BG/B2
// r6 with 2 px padding and gap, cells r4: unselected BG/A4 + FG/A3 text,
// selected BG/Accent Bright + Accent/Main text.
T.Control {
    id: root

    // [{ text: "1x", value: 1.0 }, ...]
    property var values: []
    property int currentIndex: -1

    signal activated(int index, var value)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    implicitHeight: VLCStyle.dropdown_height
    implicitWidth: Math.max(VLCStyle.dp(240, VLCStyle.scale), row.implicitWidth + leftPadding + rightPadding)

    padding: VLCStyle.space_2

    focusPolicy: Qt.StrongFocus

    Keys.onLeftPressed: (event) => {
        if (currentIndex > 0) { activated(currentIndex - 1, values[currentIndex - 1].value); event.accepted = true }
        else Navigation.defaultKeyAction(event)
    }
    Keys.onRightPressed: (event) => {
        if (currentIndex < values.length - 1) { activated(currentIndex + 1, values[currentIndex + 1].value); event.accepted = true }
        else Navigation.defaultKeyAction(event)
    }

    background: Rectangle {
        radius: VLCStyle.radius_medium
        color: theme.palette.bgB2
        border.width: root.visualFocus ? VLCStyle.focus_border : 0
        border.color: theme.visualFocus
    }

    contentItem: Row {
        id: row

        spacing: VLCStyle.space_2

        Repeater {
            model: root.values

            delegate: Rectangle {
                id: cell

                required property int index
                required property var modelData

                readonly property bool selected: index === root.currentIndex

                width: (row.width - row.spacing * (root.values.length - 1)) / Math.max(1, root.values.length)
                height: row.height
                radius: VLCStyle.radius_small

                color: selected ? theme.palette.bgAccentBright
                                : (cellHover.hovered ? Qt.lighter(theme.palette.bgA4, theme.palette.isDark ? 1.35 : 1.05)
                                                     : theme.palette.bgA4)

                T.Label {
                    anchors.centerIn: parent
                    text: cell.modelData.text
                    color: cell.selected ? theme.palette.accentMain : theme.palette.fgA3
                    font.pixelSize: VLCStyle.fontSize_body
                }

                HoverHandler { id: cellHover }

                TapHandler {
                    onTapped: root.activated(cell.index, cell.modelData.value)
                }
            }
        }
    }
}
