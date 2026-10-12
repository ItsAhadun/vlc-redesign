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

// Always visible rounded search field of the library header
// (design/SPEC.md 2.1: "Search" placeholder, 32 high, BG/A5)
FocusScope {
    id: root

    // the ColorContext palette is null until it is inherited from a parent context
    readonly property var _palette: theme.palette ?? VLCStyle.palette

    // Properties

    property alias text: textField.text
    property alias placeholderText: textField.placeholderText
    property alias textField: textField

    // the pattern, compressed while typing
    property string searchPattern

    Binding on searchPattern {
        delayed: true
        value: textField.text
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.TextField
        focused: textField.activeFocus
        hovered: textField.hovered
        enabled: root.enabled
    }

    implicitWidth: VLCStyle.dp(324, VLCStyle.scale)
    implicitHeight: VLCStyle.searchField_height

    Accessible.role: Accessible.EditableText
    Accessible.name: qsTr("Search")

    // Functions

    function expandAndFocus() {
        textField.forceActiveFocus(Qt.ShortcutFocusReason)
        textField.selectAll()
    }

    function clear() {
        textField.clear()
    }

    // Children

    T.TextField {
        id: textField

        anchors.fill: parent

        focus: true

        leftPadding: VLCStyle.space_8 + VLCStyle.icon_normal + VLCStyle.space_8
        rightPadding: clearButton.visible ? clearButton.width + VLCStyle.space_4 : VLCStyle.space_8
        topPadding: 0
        bottomPadding: 0

        verticalAlignment: Text.AlignVCenter

        font.pixelSize: VLCStyle.fontSize_body
        color: root._palette.fgA2
        placeholderText: qsTr("Search")
        placeholderTextColor: root._palette.fgA4
        selectedTextColor: theme.fg.highlight
        selectionColor: theme.bg.highlight
        selectByMouse: true

        Accessible.searchEdit: true

        background: Rectangle {
            radius: VLCStyle.radius_medium
            color: root._palette.bgA5
            border.width: textField.activeFocus ? VLCStyle.focus_border : 0
            border.color: root._palette.dividerBright
        }

        // the global shortcuts must not steal the keys typed in the field
        onActiveFocusChanged: MainCtx.useGlobalShortcuts = !activeFocus

        Navigation.parentItem: root
        Navigation.rightItem: clearButton.visible ? clearButton : null
        Navigation.cancelAction: function() {
            if (textField.text.length > 0)
                textField.clear()
            else
                root.Navigation.defaultNavigationCancel()
        }

        Keys.priority: Keys.AfterItem
        Keys.onPressed: (event) => {
            //we don't want Navigation.cancelAction to match Backspace
            if (event.matches(StandardKey.Backspace))
                event.accepted = true
            Navigation.defaultKeyAction(event)
        }
    }

    // T.TextField does not draw its placeholder
    Text {
        anchors.left: parent.left
        anchors.leftMargin: textField.leftPadding
        anchors.right: parent.right
        anchors.rightMargin: textField.rightPadding
        anchors.verticalCenter: parent.verticalCenter

        visible: textField.text.length === 0 && textField.preeditText.length === 0
        text: textField.placeholderText
        elide: Text.ElideRight
        font: textField.font
        color: textField.placeholderTextColor
    }

    Widgets.IconLabel {
        anchors.left: parent.left
        anchors.leftMargin: VLCStyle.space_8
        anchors.verticalCenter: parent.verticalCenter

        // TODO(icons): redesign "search" glyph
        text: VLCIcons.search
        font.pixelSize: VLCStyle.icon_normal
        color: root._palette.fgA3
    }

    Widgets.IconToolButton {
        id: clearButton

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.space_4
        anchors.verticalCenter: parent.verticalCenter

        width: VLCStyle.icon_normal
        height: VLCStyle.icon_normal

        visible: textField.text.length > 0

        text: VLCIcons.close
        font.pixelSize: VLCStyle.icon_small
        description: qsTr("Clear")

        Navigation.parentItem: root
        Navigation.leftItem: textField

        onClicked: {
            textField.clear()
            textField.forceActiveFocus(Qt.MouseFocusReason)
        }
    }
}
