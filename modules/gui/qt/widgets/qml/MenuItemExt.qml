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
import VLC.Widgets as Widgets
import VLC.Style

// Menu option row (design/SPEC.md 3.9, "Menu option" 2107:5935):
// 48 high, 24 px icon at x 14, label at x 48 (14 px FG/A2), right part is
// either a shortcut text (FG/A3) or a chevron when the row opens a submenu.
T.MenuItem {
    id: control

    // VLCIcons glyph, empty for no icon (the label stays aligned)
    property string iconText: (control.subMenu as MenuExt)?.iconText ?? ""

    // displayed only, the shortcut itself is handled globally
    property string shortcutText: ""

    // "selected" state (e.g. the current sort key): accent text and icon
    property bool selected: false

    readonly property ColorContext _theme: control.menu?._theme ?? fallbackTheme
    readonly property var _palette: _theme?.palette ?? VLCStyle.palette

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: visible ? VLCStyle.menuRow_height : 0

    width: control.menu ? control.menu.rowWidth : implicitWidth

    leftPadding: VLCStyle.space_14
    rightPadding: VLCStyle.space_14
    spacing: VLCStyle.space_10

    // checkable items show their state as "selected"
    readonly property bool _accent: control.selected || control.checked

    ColorContext {
        id: fallbackTheme
        colorSet: ColorContext.Window
    }

    background: Rectangle {
        implicitHeight: VLCStyle.menuRow_height
        radius: VLCStyle.radius_small
        color: (control.highlighted || control.down) ? control._palette.bgA1 : "transparent"
        border.width: control.visualFocus ? VLCStyle.focus_border : 0
        border.color: control._theme.visualFocus
    }

    contentItem: Item {
        implicitHeight: VLCStyle.icon_normal
        implicitWidth: VLCStyle.icon_normal + control.spacing + label.implicitWidth
                       + (rightPart.visible ? control.spacing + rightPart.implicitWidth : 0)

        Widgets.IconLabel {
            id: icon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            width: VLCStyle.icon_normal
            height: VLCStyle.icon_normal

            text: control.iconText
            visible: text.length > 0
            font.pixelSize: VLCStyle.icon_normal
            color: control._accent ? control._palette.accentMain
                                   : control._palette.fgA2
        }

        Text {
            id: label

            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.icon_normal + control.spacing
            anchors.right: rightPart.visible ? rightPart.left : parent.right
            anchors.rightMargin: rightPart.visible ? control.spacing : 0
            anchors.verticalCenter: parent.verticalCenter

            text: control.text
            elide: Text.ElideRight
            font.pixelSize: VLCStyle.fontSize_body
            color: !control.enabled ? control._palette.fgA4
                                    : control._accent ? control._palette.accentMain
                                                      : control._palette.fgA2
            Accessible.ignored: true
        }

        Item {
            id: rightPart

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            visible: !!control.subMenu || control.shortcutText.length > 0

            implicitWidth: control.subMenu ? chevron.implicitWidth : shortcut.implicitWidth
            implicitHeight: VLCStyle.icon_normal
            width: implicitWidth
            height: implicitHeight

            Text {
                id: shortcut

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                visible: !control.subMenu
                text: control.shortcutText
                font.pixelSize: VLCStyle.fontSize_body
                color: control._palette.fgA3
            }

            Widgets.IconLabel {
                id: chevron

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                visible: !!control.subMenu
                // TODO(icons): redesign chevron-right glyph
                text: VLCIcons.ic_fluent_chevron_right_24
                font.pixelSize: VLCStyle.icon_normal
                color: control._palette.fgA2
            }
        }
    }

    // the radio/check indicator is expressed with the accent color
    indicator: null
    arrow: null
}
