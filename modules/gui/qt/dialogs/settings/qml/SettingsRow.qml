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
import VLC.Dialogs

// One settings row (design/SPEC.md 2.3): label (14px FG/A2) + optional info
// icon with the option's long help as tool tip, control right-aligned in the
// 320 px control column (toggles: 68 px at the right edge). The row height is
// the control height + 10 (pitch 42 for toggles, 46 for 36 px controls).
//
// `row` describes the setting (see SettingsPages.qml):
//   label, type, key, info, help, invert, choices, get(), set(v),
//   enabledWhen(), scale, suffix, decimals, step, from, to, ticks, browse,
//   buttonText, wide, action()
FocusScope {
    id: root

    required property var row

    readonly property var pal: VLCStyle.palette
    readonly property string type: row.type ?? "toggle"
    readonly property bool optionExists: !row.key || SettingsBackend.exists(row.key)
    readonly property bool rowEnabled: {
        SettingsBackend.revision
        if (!optionExists || row.unavailable)
            return false
        return row.enabledWhen ? !!row.enabledWhen() : true
    }

    // current value of the setting (re-evaluated after every write)
    readonly property var value: {
        SettingsBackend.revision
        if (row.get)
            return row.get()
        if (!row.key || !optionExists)
            return undefined
        const v = SettingsBackend.value(row.key)
        return (row.scale && typeof v === "number") ? v / row.scale : v
    }

    function write(v) {
        if (row.set) {
            row.set(v)
            return
        }
        if (!row.key)
            return
        SettingsBackend.setValue(row.key, (row.scale && typeof v === "number") ? v * row.scale : v)
    }

    readonly property string helpText: {
        if (row.unavailable)
            return row.unavailable
        if (!optionExists)
            return qsTr("This setting is not available in this version of VLC.")
        if (row.help)
            return row.help
        return row.key ? SettingsBackend.longText(row.key) : ""
    }

    readonly property var choiceList: {
        SettingsBackend.revision
        if (typeof row.choices === "function")
            return row.choices()
        if (row.choices)
            return row.choices
        if (!row.key || !optionExists)
            return []
        const list = SettingsBackend.choices(row.key)
        // module options: "" means automatic selection
        if (typeof value === "string" && !list.some((c) => c.value === value))
            list.unshift({ value: value, text: value === "" ? qsTr("Automatic") : value })
        return list
    }

    implicitWidth: VLCStyle.dp(784, VLCStyle.scale)
    implicitHeight: Math.max(controlLoader.implicitHeight, VLCStyle.toggle_height) + VLCStyle.space_10

    Accessible.role: Accessible.Grouping
    Accessible.name: row.label

    Text {
        id: label

        visible: root.type !== "addons"

        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: controlLoader.labelOffset
        width: Math.min(implicitWidth,
                        controlLoader.x - VLCStyle.space_20 - (infoIcon.visible ? infoIcon.width + VLCStyle.space_10 : 0))
        text: root.row.label
        font.pixelSize: VLCStyle.fontSize_body
        color: root.pal.fgA2
        // dim disabled rows with opacity: FG/A4 is not dim in the light theme
        opacity: root.rowEnabled ? 1 : 0.45
        elide: Text.ElideRight
    }

    Widgets.IconLabel {
        id: infoIcon

        // disabled rows always explain why
        visible: (root.row.info ?? false) || (!root.rowEnabled && root.helpText !== "")
        anchors.left: label.right
        anchors.leftMargin: VLCStyle.space_10
        anchors.verticalCenter: label.verticalCenter
        text: VLCIcons.info
        font.pixelSize: VLCStyle.icon_info
        color: infoHover.hovered ? root.pal.fgA2 : root.pal.fgA3

        HoverHandler {
            id: infoHover
            cursorShape: Qt.WhatsThisCursor
        }

        Widgets.ToolTipExt {
            visible: infoHover.hovered && root.helpText !== ""
            text: root.helpText
            delay: VLCStyle.delayToolTipAppear
            width: Math.min(implicitWidth, VLCStyle.dp(360, VLCStyle.scale))
            y: infoIcon.height + VLCStyle.space_4
        }
    }

    Loader {
        id: controlLoader

        // vertical offset of the label (two-line controls keep it on the first line)
        readonly property real labelOffset: item && item.labelOffset !== undefined ? item.labelOffset : 0

        anchors.right: root.type === "addons" ? undefined : parent.right
        anchors.left: root.type === "addons" ? parent.left : undefined
        anchors.verticalCenter: parent.verticalCenter
        enabled: root.rowEnabled
        opacity: root.rowEnabled ? 1 : 0.45
        focus: true

        sourceComponent: {
            switch (root.type) {
            case "toggle": return toggleComponent
            case "dropdown": return dropdownComponent
            case "segmented": return segmentedComponent
            case "accent": return accentComponent
            case "text":
            case "password":
            case "spin":
            case "color": return textComponent
            case "path": return pathComponent
            case "slider": return sliderComponent
            case "button": return buttonComponent
            case "startupVolume": return startupVolumeComponent
            case "addons": return addonsComponent
            default: return null
            }
        }
    }

    Component {
        id: toggleComponent

        SettingsToggle {
            checked: root.row.invert ? !root.value : !!root.value
            onToggled: root.write(root.row.invert ? !checked : checked)
            Accessible.name: root.row.label
            Accessible.description: root.helpText
        }
    }

    Component {
        id: dropdownComponent

        SettingsDropdown {
            model: root.choiceList
            selectedValue: root.value
            onPicked: (v) => root.write(v)
            Accessible.description: root.helpText
        }
    }

    Component {
        id: segmentedComponent

        SettingsSegmented {
            model: root.choiceList
            selectedValue: root.value
            onPicked: (v) => root.write(v)
            Accessible.name: root.row.label
        }
    }

    Component {
        id: accentComponent

        SettingsAccentSwatches { }
    }

    Component {
        id: textComponent

        SettingsTextField {
            readonly property var range: root.row.key && root.optionExists ? SettingsBackend.range(root.row.key) : ({})

            numeric: root.type === "spin"
            echoMode: root.type === "password" ? TextInput.Password : TextInput.Normal
            placeholderText: root.row.placeholder ?? ""
            suffix: root.row.suffix ?? ""
            decimals: root.row.decimals ?? 0
            step: root.row.step ?? 1
            minimum: root.row.from ?? (range.min !== undefined ? range.min / (root.row.scale ?? 1) : -Number.MAX_VALUE)
            maximum: root.row.to ?? (range.max !== undefined ? range.max / (root.row.scale ?? 1) : Number.MAX_VALUE)
            numberValue: numeric ? Number(root.value ?? 0) : 0
            showSwatch: root.type === "color"
            swatchColor: showSwatch ? "#" + ("000000" + Number(root.value ?? 0).toString(16)).slice(-6) : "transparent"

            valueText: {
                if (root.type === "spin")
                    return formatNumber(Number(root.value ?? 0))
                if (root.type === "color")
                    return "#" + ("000000" + Number(root.value ?? 0).toString(16).toUpperCase()).slice(-6)
                return root.value ?? ""
            }

            onCommitted: (t) => {
                if (root.type === "color") {
                    const m = /^#?([0-9a-fA-F]{6})$/.exec(t.trim())
                    if (m)
                        root.write(parseInt(m[1], 16))
                    else
                        text = valueText
                } else if (t !== (root.value ?? "")) {
                    root.write(t)
                }
            }
            onNumberCommitted: (v) => root.write(v)

            Accessible.name: root.row.label
            Accessible.description: root.helpText
        }
    }

    Component {
        id: pathComponent

        Row {
            spacing: VLCStyle.space_10

            SettingsTextField {
                id: pathField
                width: VLCStyle.settingsRow_controlWidth - VLCStyle.dialogButton_width - VLCStyle.space_10
                valueText: root.value ?? ""
                placeholderText: root.row.placeholder ?? ""
                onCommitted: (t) => { if (t !== (root.value ?? "")) root.write(t) }
                Accessible.name: root.row.label
            }

            SettingsButton {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Browse")
                Accessible.name: qsTr("Browse for %1").arg(root.row.label)
                onClicked: {
                    const title = root.row.label
                    const p = root.row.browse === "file"
                            ? SettingsBackend.browseFile(title, pathField.text)
                            : SettingsBackend.browseDirectory(title, pathField.text)
                    if (p !== "")
                        root.write(p)
                }
            }
        }
    }

    Component {
        id: sliderComponent

        SettingsSlider {
            readonly property var range: root.row.key && root.optionExists ? SettingsBackend.range(root.row.key) : ({})
            readonly property real labelOffset: -tickAreaHeight / 2

            from: root.row.from ?? (range.min !== undefined ? range.min / (root.row.scale ?? 1) : 0)
            to: root.row.to ?? (range.max !== undefined ? range.max / (root.row.scale ?? 1) : 1)
            stepSize: root.row.step ?? 0
            snapMode: stepSize > 0 ? T.Slider.SnapAlways : T.Slider.NoSnap
            ticks: root.row.ticks ?? []
            value: Number(root.value ?? 0)
            valueText: root.row.format ? root.row.format(value) : ""
            onCommitted: (v) => root.write(v)

            Accessible.name: root.row.label
        }
    }

    Component {
        id: buttonComponent

        SettingsButton {
            id: actionButton

            // destructive actions ask for a second click
            property bool confirming: false

            width: root.row.wide ? VLCStyle.settingsRow_controlWidth : implicitWidth
            text: confirming ? qsTr("Confirm") : root.row.buttonText
            primary: confirming
            onClicked: {
                if (root.row.confirm && !confirming) {
                    confirming = true
                    confirmTimer.restart()
                    return
                }
                confirming = false
                if (root.row.action)
                    root.row.action()
            }
            onActiveFocusChanged: if (!activeFocus) confirming = false

            Timer {
                id: confirmTimer
                interval: 4000
                onTriggered: actionButton.confirming = false
            }

            Accessible.name: root.row.buttonText + " - " + root.row.label
            Accessible.description: confirming ? qsTr("Press again to confirm") : root.helpText
        }
    }

    Component {
        id: addonsComponent

        Row {
            spacing: VLCStyle.space_10

            SettingsTextField {
                id: addonSearch
                width: VLCStyle.dp(405, VLCStyle.scale)
                height: VLCStyle.dialogButton_height
                placeholderText: root.row.label
                Accessible.name: root.row.label
                onAccepted: SettingsBackend.openAddonsManager()
            }

            SettingsButton {
                text: qsTr("Add")
                onClicked: SettingsBackend.openAddonsManager()
            }

            SettingsButton {
                text: qsTr("Remove")
                onClicked: SettingsBackend.openAddonsManager()
            }
        }
    }

    Component {
        id: startupVolumeComponent

        SettingsStartupVolume { }
    }
}
