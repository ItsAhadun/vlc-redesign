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

// Redesign popup menu (design/SPEC.md 3.9): rounded floating panel with
// 48 px rows (icon, label, shortcut or submenu chevron) and full width
// separators. Use MenuItemExt / MenuSeparatorExt as children, nested
// MenuExt for submenus.
T.Menu {
    id: control

    // icon of the row opening this menu as a submenu (VLCIcons glyph)
    property string iconText: ""

    // the width of a row, the menu adds its padding around it
    property real rowWidth: VLCStyle.dp(257, VLCStyle.scale)

    // set to VLCStyle.darkPalette when shown over the (always dark) player,
    // popups do not inherit the palette of their visual parent
    property var menuPalette: VLCStyle.palette

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding)

    padding: VLCStyle.space_4

    margins: VLCStyle.space_8
    overlap: VLCStyle.space_4

    // submenu cascade
    cascade: true

    delegate: MenuItemExt { }

    ColorContext {
        id: theme
        colorSet: ColorContext.Window
        palette: control.menuPalette ?? VLCStyle.palette
    }

    // keep the menu theme for the items
    readonly property ColorContext _theme: theme

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: VLCStyle.duration_veryShort }
    }

    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: VLCStyle.duration_veryShort }
    }

    contentItem: ListView {
        implicitHeight: contentHeight
        implicitWidth: control.rowWidth

        model: control.contentModel
        interactive: Window.window
                     ? contentHeight + control.topPadding + control.bottomPadding > Window.window.height
                     : false
        clip: interactive
        currentIndex: control.currentIndex
        boundsBehavior: Flickable.StopAtBounds
    }

    // "bg blur + shadow" style: BG/A3 Transparent with the popup drop shadow
    background: Rectangle {
        implicitWidth: control.rowWidth + control.leftPadding + control.rightPadding
        implicitHeight: VLCStyle.menuRow_height

        radius: VLCStyle.radius_large
        // BG/A3 Transparent is meant to be drawn over a 50 px backdrop blur,
        // which menus do not have yet: keep it nearly opaque to stay readable
        // TODO: backdrop blur (FrostedGlassEffect) and the token alpha
        color: Qt.alpha(theme.palette.bgA3Transparent, 0.97)

        Widgets.RoundedRectangleShadow {
            blurRadius: VLCStyle.popupShadow_blurRadius
            yOffset: VLCStyle.popupShadow_yOffset
            color: VLCStyle.popupShadow_color
        }
    }

    T.Overlay.modal: Rectangle {
        color: "transparent"
    }

    T.Overlay.modeless: Rectangle {
        color: "transparent"
    }
}
