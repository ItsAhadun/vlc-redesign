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
import VLC.Dialogs

// "Startup volume" two-row segmented control (design/SPEC.md 3.6, 320x78):
// "Remember last volume" (volume-save) / "Always starts at:" + a percentage
// field written to the audio output's own startup volume option (as the
// classic preferences do: mmdevice/waveout on Windows, ALSA/JACK gain).
FocusScope {
    id: control

    readonly property var pal: VLCStyle.palette
    readonly property real rowHeight: VLCStyle.dropdown_height
    // keep the label on the first line
    readonly property real labelOffset: -(height - rowHeight) / 2 + VLCStyle.space_2

    // [option, cubic] in priority order
    readonly property var volumeOptions: [
        ["mmdevice-volume", false], ["waveout-volume", false],
        ["alsa-gain", true], ["jack-gain", true]
    ]
    readonly property var availableOptions: volumeOptions.filter((o) => SettingsBackend.exists(o[0]))
    readonly property bool canSetVolume: availableOptions.length > 0

    readonly property bool remember: {
        SettingsBackend.revision
        return !canSetVolume || !!SettingsBackend.value("volume-save")
    }
    readonly property int percent: {
        SettingsBackend.revision
        if (!canSetVolume)
            return 100
        const o = availableOptions[0]
        const v = Number(SettingsBackend.value(o[0]))
        return Math.round((o[1] ? Math.cbrt(v) : v) * 100)
    }

    function setPercent(p) {
        for (const o of availableOptions) {
            const v = p / 100
            SettingsBackend.setValue(o[0], o[1] ? v * v * v : v)
        }
    }

    implicitWidth: VLCStyle.settingsRow_controlWidth
    implicitHeight: 2 * rowHeight + 3 * VLCStyle.space_2

    activeFocusOnTab: true
    Keys.onUpPressed: SettingsBackend.setValue("volume-save", true)
    Keys.onDownPressed: if (canSetVolume) SettingsBackend.setValue("volume-save", false)

    Rectangle {
        anchors.fill: parent
        color: control.pal.bgB2
        radius: VLCStyle.radius_medium
    }

    Column {
        anchors.fill: parent
        anchors.margins: VLCStyle.space_2
        spacing: VLCStyle.space_2

        Repeater {
            model: 2

            delegate: Rectangle {
                id: option

                required property int index
                readonly property bool selected: (index === 0) === control.remember

                width: parent.width
                height: control.rowHeight
                radius: VLCStyle.radius_small
                color: selected ? control.pal.bgAccentBright : control.pal.bgA4
                opacity: (index === 1 && !control.canSetVolume) ? 0.4 : 1

                Accessible.role: Accessible.RadioButton
                Accessible.name: optionText.text
                Accessible.checked: selected

                Text {
                    id: optionText
                    x: VLCStyle.space_12
                    anchors.verticalCenter: parent.verticalCenter
                    text: option.index === 0 ? qsTr("Remember last volume") : qsTr("Always starts at:")
                    font.pixelSize: VLCStyle.fontSize_body
                    color: option.selected ? control.pal.accentMain : control.pal.fgA3
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: option.index === 0 || control.canSetVolume
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsBackend.setValue("volume-save", option.index === 0)
                }

                SettingsTextField {
                    visible: option.index === 1
                    enabled: control.canSetVolume
                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.space_2
                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.dp(182, VLCStyle.scale)
                    height: control.rowHeight - 2 * VLCStyle.space_2
                    opacity: option.selected ? 1 : 0.4
                    numeric: true
                    minimum: 0
                    maximum: 125
                    step: 5
                    suffix: "%"
                    numberValue: control.percent
                    valueText: String(control.percent)
                    onActiveFocusChanged: if (activeFocus && control.remember) SettingsBackend.setValue("volume-save", false)
                    onNumberCommitted: (v) => control.setPercent(v)
                    Accessible.name: qsTr("Startup volume")
                }
            }
        }
    }
}
