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
import VLC.Widgets as Widgets

// Dropdown (design/SPEC.md 2.3 / 3.8): 320x36, BG/B2 track with a BG/A4 cell,
// value FG/A2 at x 14, chevron at the right. `model` is a list of
// { value, text } objects; `currentValue` is the selected value.
T.ComboBox {
    id: control

    readonly property var pal: VLCStyle.palette
    property var selectedValue
    signal picked(var value)

    textRole: "text"
    valueRole: "value"

    implicitWidth: VLCStyle.settingsRow_controlWidth
    implicitHeight: VLCStyle.dropdown_height

    leftPadding: VLCStyle.space_14
    rightPadding: VLCStyle.icon_normal + VLCStyle.space_10 + VLCStyle.space_4
    font.pixelSize: VLCStyle.fontSize_body

    currentIndex: indexForValue(selectedValue)

    // loose comparison: vlcrc floats come back as float32 (0.06 -> 0.0599...)
    function sameValue(a, b) {
        if (typeof a === "number" && typeof b === "number")
            return Math.abs(a - b) < 1e-4
        if (typeof a === "boolean" || typeof b === "boolean")
            return !!a === !!b
        return a == b // eslint-disable-line eqeqeq
    }

    function indexForValue(v) {
        const m = control.model
        if (!m)
            return -1
        for (let i = 0; i < m.length; ++i) {
            // loose comparison: vlcrc integers come as numbers, choices too
            if (control.sameValue(m[i].value, v))
                return i
        }
        return -1
    }

    onActivated: (index) => {
        if (index >= 0 && index < model.length)
            picked(model[index].value)
    }

    Accessible.name: displayText

    background: Rectangle {
        color: control.pal.bgB2
        radius: VLCStyle.radius_medium
        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: control.pal.accentMain

        Rectangle {
            anchors.fill: parent
            anchors.margins: VLCStyle.space_2
            radius: VLCStyle.radius_small
            color: control.hovered || control.popup.visible ? Qt.lighter(control.pal.bgA4, 1.2) : control.pal.bgA4
        }
    }

    contentItem: Text {
        text: control.currentIndex >= 0 ? control.displayText : "-"
        font: control.font
        color: control.enabled ? control.pal.fgA2 : control.pal.fgA4
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Widgets.IconLabel {
        x: control.width - width - VLCStyle.space_10 - VLCStyle.space_4
        y: (control.height - height) / 2
        text: VLCIcons.chevron_down
        font.pixelSize: VLCStyle.icon_normal
        color: control.enabled ? control.pal.fgA2 : control.pal.fgA4
        rotation: control.popup.visible ? 180 : 0
    }

    delegate: T.ItemDelegate {
        required property int index
        required property var modelData

        width: ListView.view ? ListView.view.width : control.width
        height: VLCStyle.dropdown_height
        leftPadding: VLCStyle.space_12
        rightPadding: VLCStyle.space_12
        highlighted: control.highlightedIndex === index

        contentItem: Text {
            text: modelData.text
            font.pixelSize: VLCStyle.fontSize_body
            color: index === control.currentIndex ? control.pal.accentMain
                 : (parent.highlighted ? (control.pal.isDark ? control.pal.fg1 : control.pal.fgB1) : control.pal.fgA2)
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: VLCStyle.radius_small
            color: parent.highlighted ? control.pal.hoverOverlay : "transparent"
        }
    }

    popup: T.Popup {
        y: control.height + VLCStyle.space_4
        width: control.width
        height: Math.min(contentItem.implicitHeight + topPadding + bottomPadding,
                         VLCStyle.dropdown_height * 8 + topPadding + bottomPadding)
        padding: VLCStyle.space_4

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }
        }

        background: Rectangle {
            color: control.pal.bgA3
            radius: VLCStyle.radius_medium
            border.width: VLCStyle.dp(1, VLCStyle.scale)
            border.color: control.pal.dividerDim

            Widgets.RoundedRectangleShadow {
                blurRadius: VLCStyle.popupShadow_blurRadius
                yOffset: VLCStyle.popupShadow_yOffset
                color: VLCStyle.popupShadow_color
            }
        }
    }
}
