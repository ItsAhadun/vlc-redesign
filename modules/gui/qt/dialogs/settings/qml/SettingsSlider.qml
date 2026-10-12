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

// Slider (design/SPEC.md 2.3): 320 wide, BG/B2 track, played part
// BG/Accent Bright, Accent/Main handle (same language as the seek bar), with
// optional tick labels under it. `ticks` is a list of { value, label }.
T.Slider {
    id: control

    readonly property var pal: VLCStyle.palette
    property var ticks: []
    // text shown in the handle tooltip while dragging
    property string valueText: ""

    // emitted when the user moved the handle (not on external value changes)
    signal committed(real newValue)

    readonly property real trackHeight: VLCStyle.dp(6, VLCStyle.scale)
    readonly property real handleHeight: VLCStyle.dp(20, VLCStyle.scale)
    readonly property real tickAreaHeight: ticks.length > 0 ? VLCStyle.dp(23, VLCStyle.scale) : 0

    implicitWidth: VLCStyle.settingsRow_controlWidth
    implicitHeight: VLCStyle.dp(24, VLCStyle.scale) + tickAreaHeight

    focusPolicy: Qt.StrongFocus
    live: true
    padding: 0

    onMoved: committed(value)

    Keys.onLeftPressed: (event) => { decrease(); committed(value) }
    Keys.onRightPressed: (event) => { increase(); committed(value) }
    Keys.onDownPressed: (event) => { decrease(); committed(value) }
    Keys.onUpPressed: (event) => { increase(); committed(value) }

    readonly property real _trackY: (VLCStyle.dp(24, VLCStyle.scale) - trackHeight) / 2
    readonly property real _handleWidth: VLCStyle.seekHandle_width

    function xFor(v) {
        const span = to - from
        const pos = span === 0 ? 0 : (v - from) / span
        return _handleWidth / 2 + pos * (width - _handleWidth)
    }

    background: Item {
        Rectangle {
            id: track
            y: control._trackY
            width: control.width
            height: control.trackHeight
            radius: height / 2
            color: control.pal.bgB2

            Rectangle {
                width: control.xFor(control.value)
                height: parent.height
                radius: parent.radius
                color: control.pal.bgAccentBright
            }
        }

        Repeater {
            model: control.ticks

            delegate: Item {
                id: tick
                required property int index
                required property var modelData

                Rectangle {
                    x: control.xFor(tick.modelData.value) - width / 2
                    y: control._trackY + control.trackHeight + VLCStyle.space_4
                    width: VLCStyle.dp(1, VLCStyle.scale)
                    height: VLCStyle.space_4
                    color: control.pal.dividerBright
                }

                Text {
                    readonly property real center: control.xFor(tick.modelData.value)
                    x: Math.max(0, Math.min(control.width - width, center - width / 2))
                    y: control._trackY + control.trackHeight + VLCStyle.space_10
                    text: tick.modelData.label
                    font.pixelSize: VLCStyle.fontSize_caption
                    color: control.pal.fgA3
                }
            }
        }
    }

    handle: Rectangle {
        x: control.xFor(control.value) - width / 2
        y: control._trackY + control.trackHeight / 2 - height / 2
        width: control._handleWidth
        height: control.handleHeight
        radius: VLCStyle.radius_xxsmall
        color: control.pressed || control.hovered ? control.pal.accentBright : control.pal.accentMain
        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: (control.pal.isDark ? control.pal.fg1 : control.pal.fgB1)
    }

    T.ToolTip {
        parent: control.handle
        visible: control.pressed && control.valueText !== ""
        x: (parent.width - width) / 2
        y: -height - VLCStyle.space_6
        padding: VLCStyle.space_6
        contentItem: Text {
            text: control.valueText
            font.pixelSize: VLCStyle.fontSize_caption
            color: control.pal.fgA2
        }
        background: Rectangle {
            color: control.pal.bgA3
            radius: VLCStyle.radius_small
            border.width: VLCStyle.dp(1, VLCStyle.scale)
            border.color: control.pal.dividerDim
        }
    }
}
