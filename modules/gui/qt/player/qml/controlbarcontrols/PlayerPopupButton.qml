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
import QtQuick.Window

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style

// Control bar icon button that toggles a PlayerPopup (popupComponent) above
// the control bar. The popup is created on first use.
Widgets.IconToolButton {
    id: root

    property Component popupComponent: null

    readonly property bool popupOpened: popupLoader.item?.opened ?? false

    // Signals

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)

    // Private

    readonly property Item _parentItem: {
        if ((typeof rootPlayer !== 'undefined') && (rootPlayer !== null))
            return rootPlayer
        return root.Window.contentItem
    }

    property double _closedAt: 0

    // Settings

    checked: popupOpened

    // Events

    onClicked: {
        if (paintOnly || !popupComponent)
            return

        // the press that closed the popup should not reopen it
        if (Date.now() - _closedAt < 250)
            return

        popupLoader.active = true
        const popup = popupLoader.item
        if (!popup)
            return
        if (popup.opened)
            popup.close()
        else
            popup.open()
    }

    function forceUnlock() {
        popupLoader.item?.close()
    }

    // Children

    Loader {
        id: popupLoader

        active: false
        sourceComponent: root.popupComponent

        onLoaded: {
            const popup = item
            popup.parent = root._parentItem
            popup.anchorItem = root
            popup.aboutToShow.connect(() => {
                root.requestLockUnlockAutoHide(true)
                root.menuOpened(popup)
            })
            popup.aboutToHide.connect(() => {
                root._closedAt = Date.now()
                root.requestLockUnlockAutoHide(false)
                root.menuOpened(null)
            })
        }
    }
}
