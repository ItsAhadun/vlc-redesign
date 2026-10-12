/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
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
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

// Navigation pane entry (design/SPEC.md 2.1): 24 px icon + 14 px label,
// icon only when the pane is collapsed to the rail. The current entry has
// its icon in the accent color and a brighter label.
T.ItemDelegate {
    id: control

    // Properties

    property string iconTxt: ""

    property bool showText: true

    property real radius: VLCStyle.radius_small

    property string accessibleId: ""

    // Settings

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: VLCStyle.dp(46, VLCStyle.scale)

    leftPadding: showText ? VLCStyle.space_12 : 0
    rightPadding: showText ? VLCStyle.space_12 : 0
    topPadding: 0
    bottomPadding: 0

    spacing: VLCStyle.space_12

    focusPolicy: Qt.StrongFocus

    // Accessible

    Accessible.onPressAction: control.clicked()
    Accessible.name: text
    AccessibleCompat.id: accessibleId

    // Tooltip

    T.ToolTip.visible: (showText === false && T.ToolTip.text && (hovered || visualFocus))

    T.ToolTip.delay: VLCStyle.delayToolTipAppear

    T.ToolTip.text: text

    // Childs

    readonly property bool _current: control.checked || control.highlighted

    ColorContext {
        id: theme
        colorSet: ColorContext.Window

        focused: control.visualFocus
        hovered: control.hovered
        pressed: control.down
        enabled: control.enabled
    }

    background: Rectangle {
        radius: control.radius
        color: ((control.hovered || control.down) ? theme.palette?.hoverOverlay : undefined) ?? "transparent"
        border.width: control.visualFocus ? VLCStyle.focus_border : 0
        border.color: theme.visualFocus
    }

    contentItem: Item {
        implicitWidth: VLCStyle.icon_normal + (control.showText ? control.spacing + label.implicitWidth : 0)
        implicitHeight: VLCStyle.icon_normal

        Widgets.IconLabel {
            id: iconLabel

            x: control.showText ? 0 : Math.round((parent.width - width) / 2)
            anchors.verticalCenter: parent.verticalCenter

            width: VLCStyle.icon_normal
            height: VLCStyle.icon_normal

            text: control.iconTxt

            font.pixelSize: VLCStyle.icon_normal

            color: (control._current ? theme.palette?.accentMain
                                     : (control.hovered ? (theme.palette?.isDark ? theme.palette?.fg1 : theme.palette?.fgA1)
                                                        : theme.palette?.fgA2)) ?? "transparent"
        }

        Text {
            id: label

            anchors.left: iconLabel.right
            anchors.leftMargin: control.spacing
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            visible: control.showText

            text: control.text

            elide: Text.ElideRight

            font.pixelSize: VLCStyle.fontSize_body

            color: ((control._current || control.hovered) ? (theme.palette?.isDark ? theme.palette?.fg1 : theme.palette?.fgA1)
                                                          : theme.palette?.fgA2) ?? "transparent"

            //button text is already exposed
            Accessible.ignored: true
        }
    }
}
