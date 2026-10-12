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
import VLC.PlayerControls
import VLC.Player

// "Customize Player" modal (design/SPEC.md 2.1 Player - customize 2107:5604):
// about 1048x655 centered over the player, header "Customize Player" + close,
// the help text on a darker strip, a 9 columns palette of draggable items
// (icon in a dashed box + label) and Cancel / Save. Items are dragged from the
// palette into the control bar, re-ordered there, or dragged back into the
// palette box to remove them (PlayerCustomizeRow / PlayerCustomizeDragLayer).
// Built on the control bar profile model: Save writes the profile, Cancel
// restores the saved one.
FocusScope {
    id: root

    property Item dragLayer: null

    signal finished()

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    readonly property var _profile: MainCtx.controlbarProfileModel.currentModel
    readonly property bool _dirty: !!_profile && _profile.dirty

    function cancel() {
        // restore the profile saved when entering the customize mode
        MainCtx.controlbarProfileModel.reload()
        finished()
    }

    function save() {
        MainCtx.controlbarProfileModel.save()
        finished()
    }

    property real maximumHeight: VLCStyle.dp(655, VLCStyle.scale)

    implicitWidth: VLCStyle.settingsWindow_width
    implicitHeight: Math.min(VLCStyle.dp(655, VLCStyle.scale), maximumHeight)

    Keys.onEscapePressed: cancel()

    Component.onCompleted: {
        // remember the current state, Cancel goes back to it
        MainCtx.controlbarProfileModel.save(false)
        forceActiveFocus()
    }

    // swallow the clicks so they do not reach the player
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: (wheel) => wheel.accepted = true
    }

    Rectangle {
        id: background

        anchors.fill: parent
        radius: VLCStyle.radius_large
        color: theme.palette.bgA3Transparent

        Widgets.RoundedRectangleShadow {
            blurRadius: VLCStyle.popupShadow_blurRadius
            yOffset: VLCStyle.popupShadow_yOffset
            color: VLCStyle.popupShadow_color
        }
    }

    // Header
    T.Label {
        id: title

        x: VLCStyle.space_20
        height: VLCStyle.dp(50, VLCStyle.scale)

        verticalAlignment: Text.AlignVCenter
        text: qsTr("Customize Player")
        color: theme.palette.fgA1
        font.pixelSize: VLCStyle.fontSize_body
    }

    Widgets.IconToolButton {
        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.space_10
        anchors.verticalCenter: title.verticalCenter

        width: VLCStyle.iconWrapper_height
        height: VLCStyle.iconWrapper_height

        text: VLCIcons.close
        description: qsTr("Close")
        font.pixelSize: VLCStyle.icon_normal

        onClicked: root.cancel()
    }

    Rectangle {
        id: helpStrip

        anchors.top: title.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        height: VLCStyle.dp(47, VLCStyle.scale)
        color: theme.palette.isDark ? Qt.alpha(theme.palette.bgB2, 0.6) : Qt.alpha(theme.palette.bgA4, 0.6)

        T.Label {
            anchors.verticalCenter: parent.verticalCenter
            x: VLCStyle.space_20
            width: parent.width - VLCStyle.space_20 * 2

            text: qsTr("Drag items around and out of the box below to re-order them. Drag items into the box to remove them from the player.")
            elide: Text.ElideRight
            color: theme.palette.fgA3
            font.pixelSize: VLCStyle.fontSize_body
        }
    }

    // Palette box: drop bar items here to remove them
    Item {
        id: paletteBox

        anchors.top: helpStrip.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right

        Rectangle {
            anchors.fill: parent
            anchors.margins: VLCStyle.space_8
            radius: VLCStyle.radius_small
            visible: dropArea.containsDrag && (dropArea.drag.source?.sourceModel ?? null) !== null
            color: "transparent"
            border.width: VLCStyle.dp(1, VLCStyle.scale)
            border.color: theme.palette.accentMain
        }

        GridView {
            id: grid

            anchors.fill: parent
            anchors.leftMargin: VLCStyle.dp(26, VLCStyle.scale)
            anchors.rightMargin: VLCStyle.dp(26, VLCStyle.scale)
            anchors.topMargin: VLCStyle.space_16

            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            cellWidth: Math.floor(width / 9)
            cellHeight: VLCStyle.dp(116, VLCStyle.scale) // icon + two label lines

            model: PlayerControlbarControls.customizePalette

            T.ScrollBar.vertical: Widgets.ScrollBarExt { visible: grid.interactive }

            delegate: Item {
                id: cell

                required property int modelData
                required property int index

                readonly property var _entry: PlayerControlbarControls.control(modelData)
                readonly property string _label: PlayerControlbarControls.customizeLabels[modelData] ?? _entry.text ?? ""

                width: grid.cellWidth
                height: grid.cellHeight

                opacity: dragHandler.active ? 0.4 : 1.0

                Item {
                    id: iconBox

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: VLCStyle.space_4

                    width: VLCStyle.iconWrapper_height
                    height: VLCStyle.iconWrapper_height

                    DashedOutline {
                        anchors.fill: parent
                        color: (cellHover.hovered || dragHandler.active) ? theme.palette.accentMain : theme.palette.fgA4
                    }

                    // the Thumbnail item is a filled square in the design
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: VLCStyle.space_4
                        visible: cell.modelData === ControlListModel.THUMBNAIL_WIDGET
                        radius: VLCStyle.radius_xxsmall
                        color: theme.palette.fgA4
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        visible: cell.modelData === ControlListModel.WIDGET_DIVIDER
                        width: VLCStyle.dp(1, VLCStyle.scale)
                        height: parent.height - VLCStyle.space_8
                        color: theme.palette.fgA2
                    }

                    Widgets.IconLabel {
                        anchors.centerIn: parent
                        visible: cell.modelData !== ControlListModel.THUMBNAIL_WIDGET
                                 && cell.modelData !== ControlListModel.WIDGET_DIVIDER
                                 && cell.modelData !== ControlListModel.WIDGET_SPACER_EXTEND
                        text: cell._entry.label ?? ""
                        color: cellHover.hovered ? theme.palette.fg1 : theme.palette.fgA2
                        font.pixelSize: VLCStyle.icon_normal
                    }
                }

                T.Label {
                    anchors.top: iconBox.bottom
                    anchors.topMargin: VLCStyle.space_8
                    anchors.horizontalCenter: parent.horizontalCenter

                    // narrow like the design: "Forward" / "10s" on two lines
                    width: Math.min(implicitWidth, VLCStyle.dp(80, VLCStyle.scale))

                    text: cell._label
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: VLCStyle.lineHeight_body
                    lineHeightMode: Text.FixedHeight
                    color: theme.palette.fgA2
                    font.pixelSize: VLCStyle.fontSize_body
                }

                HoverHandler {
                    id: cellHover
                    cursorShape: Qt.OpenHandCursor
                }

                DragHandler {
                    id: dragHandler

                    target: null
                    enabled: !!root.dragLayer

                    onActiveChanged: {
                        if (active)
                            root.dragLayer.begin(cell.modelData, null, -1, centroid.scenePosition)
                        else
                            root.dragLayer.end()
                    }

                    onCentroidChanged: {
                        if (active)
                            root.dragLayer.move(centroid.scenePosition)
                    }
                }
            }
        }

        DropArea {
            id: dropArea

            anchors.fill: parent

            keys: ["vlc-player-control"]

            onDropped: (drop) => {
                const src = drop.source
                if (src && src.sourceModel && src.sourceIndex >= 0) {
                    src.sourceModel.remove(src.sourceIndex)
                    drop.accept(Qt.MoveAction)
                }
            }
        }
    }

    // Footer: Cancel / Save
    Item {
        id: footer

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        height: VLCStyle.dialogFooter_height

        component FooterButton: T.Button {
            id: button

            property bool primary: false

            width: VLCStyle.dialogButton_width
            height: VLCStyle.dialogButton_height

            background: Rectangle {
                radius: VLCStyle.radius_small
                color: {
                    if (!button.enabled)
                        return Qt.alpha(theme.palette.bgA4, 0.5)
                    if (button.primary)
                        return button.hovered ? theme.palette.accentBright : theme.palette.accentMain
                    return button.hovered ? theme.palette.bgA2 : theme.palette.bgA4
                }
                border.width: button.visualFocus ? VLCStyle.focus_border : 0
                border.color: theme.visualFocus
            }

            contentItem: T.Label {
                text: button.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: !button.enabled ? theme.palette.fgA4
                                       : (button.primary ? theme.palette.fgOnAccent : theme.palette.fgA2)
                font.pixelSize: VLCStyle.fontSize_body
            }
        }

        FooterButton {
            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.space_20
            anchors.verticalCenter: parent.verticalCenter

            text: qsTr("Cancel")
            onClicked: root.cancel()
        }

        FooterButton {
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.space_20
            anchors.verticalCenter: parent.verticalCenter

            primary: true
            enabled: root._dirty
            text: qsTr("Save")
            onClicked: root.save()
        }
    }
}
