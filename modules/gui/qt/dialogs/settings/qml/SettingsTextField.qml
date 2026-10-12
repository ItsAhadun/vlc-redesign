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

// Text field (design/SPEC.md 2.3, "Frame 265/266"): BG/B2 well with a
// BG/A4 border, 36 high. Also used as a spin box (`numeric`: Up/Down keys and
// the wheel step the value, `suffix` is drawn after the number) and as a
// password field.
T.TextField {
    id: control

    readonly property var pal: VLCStyle.palette

    // numeric mode
    property bool numeric: false
    property real numberValue: 0
    property real minimum: -Number.MAX_VALUE
    property real maximum: Number.MAX_VALUE
    property real step: 1
    property int decimals: 0
    property string suffix: ""
    // swatch shown before the text (color fields)
    property color swatchColor: "transparent"
    property bool showSwatch: false

    // text of the current setting value; the field shows it again after
    // every write (user edits don't break this)
    property string valueText: ""
    Binding on text { value: control.valueText }

    // emitted when the user commits a new value (Enter or focus out)
    signal committed(string newText)
    signal numberCommitted(real newValue)

    function formatNumber(v) {
        return Number(v).toFixed(decimals)
    }

    function commit() {
        if (numeric) {
            let v = parseFloat(text.replace(",", "."))
            if (isNaN(v))
                v = numberValue
            v = Math.min(maximum, Math.max(minimum, v))
            if (v !== numberValue)
                numberCommitted(v)
            else
                text = valueText
        } else {
            committed(text)
        }
    }

    function stepBy(n) {
        const v = Math.min(maximum, Math.max(minimum, numberValue + n * step))
        if (v !== numberValue)
            numberCommitted(v)
    }

    implicitWidth: VLCStyle.settingsRow_controlWidth
    implicitHeight: VLCStyle.dropdown_height

    leftPadding: VLCStyle.space_12 + (showSwatch ? swatch.width + VLCStyle.space_8 : 0)
    rightPadding: VLCStyle.space_12 + (suffixText.visible ? suffixText.implicitWidth + VLCStyle.space_4 : 0)
    verticalAlignment: TextInput.AlignVCenter

    font.pixelSize: VLCStyle.fontSize_body
    color: pal.fgA2
    placeholderTextColor: pal.fgA4
    selectionColor: pal.bgAccentBright
    selectedTextColor: pal.fg1
    selectByMouse: true

    inputMethodHints: numeric ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone

    onEditingFinished: commit()

    Keys.onUpPressed: (event) => { if (numeric) stepBy(1); else event.accepted = false }
    Keys.onDownPressed: (event) => { if (numeric) stepBy(-1); else event.accepted = false }
    Keys.onEscapePressed: (event) => {
        // let Esc close the window unless the field was edited
        event.accepted = false
    }

    WheelHandler {
        enabled: control.numeric && control.activeFocus
        onWheel: (event) => control.stepBy(event.angleDelta.y > 0 ? 1 : -1)
    }

    background: Rectangle {
        color: control.pal.bgB2
        radius: VLCStyle.radius_medium
        border.width: VLCStyle.space_2
        border.color: control.activeFocus ? control.pal.accentDim : control.pal.bgA4

        Text {
            x: control.leftPadding
            width: parent.width - control.leftPadding - control.rightPadding
            anchors.verticalCenter: parent.verticalCenter
            visible: control.text === "" && !control.preeditText
            text: control.placeholderText
            font: control.font
            color: control.placeholderTextColor
            elide: Text.ElideRight
        }

        Rectangle {
            id: swatch

            visible: control.showSwatch
            x: VLCStyle.space_12
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(16, VLCStyle.scale)
            height: width
            radius: VLCStyle.radius_xxsmall
            color: control.swatchColor
            border.width: VLCStyle.dp(1, VLCStyle.scale)
            border.color: control.pal.dividerBright
        }

        Text {
            id: suffixText

            visible: control.suffix !== ""
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.space_12
            anchors.verticalCenter: parent.verticalCenter
            text: control.suffix
            font.pixelSize: VLCStyle.fontSize_body
            color: control.pal.fgA3
        }
    }
}
