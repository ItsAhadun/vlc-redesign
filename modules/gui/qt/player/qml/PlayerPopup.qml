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

// Popup panel opened above the control bar by its buttons (the "Controls"
// variants of design/SPEC.md 3.14): BG/A3 Transparent, radius 8,
// "bg blur + shadow" style, 4 px padding, menu option rows (PopupOption).
//
// `parent` must be the player page (it provides `positionSliderY`), the
// popup is horizontally centered on `anchorItem` and kept inside the page.
T.Popup {
    id: root

    property Item anchorItem: null

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    readonly property real _anchorCenterX: {
        if (!anchorItem || !parent)
            return 0
        // re-evaluate when the popup opens
        void(root.opened)
        const p = anchorItem.mapToItem(parent, anchorItem.width / 2, 0)
        return p.x
    }

    x: Math.max(VLCStyle.space_8,
                Math.min(_anchorCenterX - width / 2, (parent ? parent.width : width) - width - VLCStyle.space_8))
    y: ((parent && parent.positionSliderY !== undefined) ? parent.positionSliderY : (parent ? parent.height : 0))
       - height - VLCStyle.space_8
    z: 10

    implicitWidth: Math.max(VLCStyle.dp(284, VLCStyle.scale), implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.min(implicitContentHeight + topPadding + bottomPadding,
                             (parent && parent.positionSliderY !== undefined) ? parent.positionSliderY - VLCStyle.titleBar_height - VLCStyle.space_16
                                                                             : Number.MAX_VALUE)

    padding: VLCStyle.space_4

    focus: true
    modal: false
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: VLCStyle.duration_short; easing.type: Easing.OutSine }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: VLCStyle.duration_short; easing.type: Easing.InSine }
    }

    background: Rectangle {
        radius: VLCStyle.radius_large
        color: theme.palette.bgA3Transparent

        Widgets.RoundedRectangleShadow {
            blurRadius: VLCStyle.popupShadow_blurRadius
            yOffset: VLCStyle.popupShadow_yOffset
            color: VLCStyle.popupShadow_color
        }
    }
}
