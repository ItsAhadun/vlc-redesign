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

import VLC.MainInterface
import VLC.MediaLibrary

import VLC.Widgets as Widgets
import VLC.Style

// "Recent" page of the navigation pane: the media library playback history
Widgets.PageExt {
    id: root

    property int displayMarginBeginning: 0
    property int displayMarginEnd: 0
    property bool enableBeginningFade: true
    property bool enableEndFade: true

    title: qsTr("Recent")

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Recent view")

    addAction: null

    moreActions: [{
        text: qsTr("Play All"),
        visible: recentModel.count > 0,
        action: () => _playAll(false)
    }, {
        text: qsTr("Enqueue All"),
        visible: recentModel.count > 0,
        action: () => _playAll(true)
    }, {
        text: qsTr("Clear History"),
        visible: recentModel.count > 0,
        action: () => recentModel.clearHistory()
    }]

    function _playAll(enqueue) {
        const indexes = []
        for (let i = 0; i < recentModel.count; ++i)
            indexes.push(recentModel.index(i, 0))
        recentModel.getData(indexes, (data) => {
            const ids = data.map((d) => d.id)
            if (enqueue)
                MediaLib.addToPlaylist(ids)
            else
                MediaLib.addAndPlay(ids)
        })
    }

    MediaView {
        id: mediaView

        anchors.fill: parent

        focus: true

        model: MLRecentMediaModel {
            id: recentModel

            ml: MediaLib

            searchPattern: root.search.pattern
        }

        // the history is ordered by playback date
        sortModel: []

        displayMarginBeginning: root.displayMarginBeginning
        displayMarginEnd: root.displayMarginEnd

        enableBeginningFade: root.enableBeginningFade
        enableEndFade: root.enableEndFade
    }
}
