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

import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

// "Favorite": marking the playing media as favorite needs a media library
// lookup of the current item which is not exposed to the player yet, the
// button is shown disabled. TODO: MediaLib API to (un)favorite by MRL.
// TODO(icons): heart icon of the redesign set
Widgets.IconToolButton {
    text: VLCIcons.active_indicator
    description: qsTr("Favorite (not available)")

    enabled: false

    AccessibleCompat.id: "favoriteButton"
}
