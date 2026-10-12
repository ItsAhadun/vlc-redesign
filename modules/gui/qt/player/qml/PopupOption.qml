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

// "Menu option" row (design/SPEC.md 3.9): 48 high, optional 24 icon at x 14,
// 14 px label at x 48, optional right part (shortcut/value text, a check or a
// chevron). Hover: hover overlay; checked: accent icon and label.
T.ItemDelegate {
    id: root

    property string iconText: ""
    property string rightText: ""
    property bool showChevron: false
    property bool showCheck: checked

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
        enabled: root.enabled
    }

    implicitWidth: Math.max(VLCStyle.dp(257, VLCStyle.scale), label.implicitWidth + VLCStyle.space_16 * 2 + VLCStyle.dp(48, VLCStyle.scale))
    implicitHeight: VLCStyle.menuRow_height

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    background: Rectangle {
        radius: VLCStyle.radius_small
        color: (root.hovered || root.visualFocus) ? theme.palette.hoverOverlay : "transparent"
        border.width: root.visualFocus ? VLCStyle.focus_border : 0
        border.color: theme.visualFocus
    }

    contentItem: Item {
        Widgets.IconLabel {
            x: VLCStyle.space_14 - root.leftPadding
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: root.iconText
            color: root.checked ? theme.palette.accentMain : theme.palette.fgA2
            font.pixelSize: VLCStyle.icon_normal
        }

        T.Label {
            id: label

            x: VLCStyle.dp(48, VLCStyle.scale) - root.leftPadding
            width: parent.width - x - right.width - VLCStyle.space_8
            anchors.verticalCenter: parent.verticalCenter

            text: root.text
            elide: Text.ElideRight
            color: !root.enabled ? theme.palette.fgA4
                                 : (root.checked ? theme.palette.accentMain : theme.palette.fgA2)
            font.pixelSize: VLCStyle.fontSize_body
        }

        Item {
            id: right

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(rightLabel.implicitWidth, rightIcon.visible ? VLCStyle.icon_normal : 0)
            height: VLCStyle.icon_normal

            T.Label {
                id: rightLabel
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== "" && !rightIcon.visible
                text: root.rightText
                color: theme.palette.fgA3
                font.pixelSize: VLCStyle.fontSize_body
            }

            Widgets.IconLabel {
                id: rightIcon
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showChevron || (root.showCheck && root.checked)
                text: root.showChevron ? VLCIcons.ic_fluent_chevron_right_24 : VLCIcons.check
                color: root.showChevron ? theme.palette.fgA3 : theme.palette.accentMain
                font.pixelSize: VLCStyle.icon_normal
            }
        }
    }

    leftPadding: VLCStyle.space_4
    rightPadding: VLCStyle.space_14
}
