/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
import VLC.Util
import VLC.Style

// Video card (design/SPEC.md 2.1): 16:9 rounded thumbnail, title below in
// FG/A2 (FG/A3 once watched) and the Accent/Main watched progress along the
// thumbnail bottom.
Widgets.GridItem {
    id: root

    // the ColorContext palette is null until it is inherited from a parent context
    readonly property var _palette: theme.palette ?? VLCStyle.palette

    property bool showNewIndicator: false
    
    property var labels

    // the media was played (until its end when there is no progress)
    readonly property bool watched: (model.isNew === false)
    readonly property real watchedProgress: {
        const progress = model.progress ?? 0
        if (progress > 0)
            return Helpers.clamp(progress, 0, 1)
        return root.watched ? 1.0 : 0.0
    }

    function play() {
        if ( model.id !== undefined ) {
            MediaLib.addAndPlay( model.id )
            MainCtx.playerView = true
        }
    }

    image: model.thumbnail || ""
    fallbackImage: VLCStyle.noArtVideoCover
    fillMode: Image.PreserveAspectCrop

    title: model.title || qsTr("Unknown title")
    // the redesign cards only show the title
    subtitle: ""
    pictureWidth: VLCStyle.videoCard_width
    pictureHeight: VLCStyle.videoCard_height
    pictureRadius: VLCStyle.radius_large

    titleTopMargin: VLCStyle.dp(19, VLCStyle.scale)
    titleWeight: VLCStyle.fontWeight_regular
    titleColor: root.selected ? theme.fg.highlight
                              : (root.watched ? root._palette.fgA3 : root._palette.fgA2)

    showShadows: false

    Widgets.VideoProgressBar {
        id: progressBar

        parent: root.mediaCover
        z: 10

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        visible: root.watchedProgress > 0

        radius: root.pictureRadius
        value: root.watchedProgress
    }

    onPlayClicked: root.play()

    ColorContext {
        id: theme
        colorSet: ColorContext.Item
    }
}
