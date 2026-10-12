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

// Segmented "Values" control (design/SPEC.md 3.6): BG/B2 track, 2 px
// padding and gap, cells BG/A4 (selected: BG/Accent Bright + Accent/Main).
// `model` is a list of { value, text }.
T.Control {
    id: control

    readonly property var pal: VLCStyle.palette
    property var model: []
    property var selectedValue
    signal picked(var value)

    // loose comparison: vlcrc floats come back as float32 (0.06 -> 0.0599...)
    function sameValue(a, b) {
        if (typeof a === "number" && typeof b === "number")
            return Math.abs(a - b) < 1e-4
        if (typeof a === "boolean" || typeof b === "boolean")
            return !!a === !!b
        return a == b // eslint-disable-line eqeqeq
    }

    readonly property int selectedIndex: {
        for (let i = 0; i < model.length; ++i)
            if (control.sameValue(model[i].value, selectedValue))
                return i
        return -1
    }

    implicitWidth: VLCStyle.settingsRow_controlWidth
    implicitHeight: VLCStyle.dropdown_height

    focusPolicy: Qt.StrongFocus
    padding: 0

    Accessible.role: Accessible.PageTabList

    Keys.onLeftPressed: (event) => {
        if (selectedIndex > 0)
            picked(model[selectedIndex - 1].value)
        else
            event.accepted = false
    }
    Keys.onRightPressed: (event) => {
        if (selectedIndex < model.length - 1)
            picked(model[selectedIndex + 1].value)
        else
            event.accepted = false
    }

    Rectangle {
        anchors.fill: parent
        color: control.pal.bgB2
        radius: VLCStyle.radius_medium
        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: control.pal.accentMain
    }

    Row {
        anchors.fill: parent
        anchors.margins: VLCStyle.space_2
        spacing: VLCStyle.space_2

        Repeater {
            model: control.model

            delegate: Rectangle {
                id: cell

                required property int index
                required property var modelData
                readonly property bool selected: index === control.selectedIndex

                width: (control.width - 2 * VLCStyle.space_2 - (control.model.length - 1) * VLCStyle.space_2) / control.model.length
                height: parent.height
                radius: VLCStyle.radius_small
                color: selected ? control.pal.bgAccentBright
                                : (mouse.containsMouse ? Qt.lighter(control.pal.bgA4, 1.2) : control.pal.bgA4)

                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.text
                Accessible.selected: selected

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: VLCStyle.space_4
                    anchors.rightMargin: VLCStyle.space_4
                    text: cell.modelData.text
                    font.pixelSize: VLCStyle.fontSize_body
                    color: cell.selected ? control.pal.accentMain : control.pal.fgA3
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        control.forceActiveFocus(Qt.MouseFocusReason)
                        control.picked(cell.modelData.value)
                    }
                }
            }
        }
    }
}
