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

pragma Singleton

import QtQml


import VLC.MainInterface
import VLC.PlayerControls
import VLC.Widgets as Widgets
import VLC.Style

QtObject {
    readonly property string controlPath : "qrc:///qt/qml/VLC/PlayerControls/"

    readonly property var controlList: [
        { id: ControlListModel.PLAY_BUTTON, file: "PlayButton.qml", label: VLCIcons.play_filled, text: qsTr("Play") },
        { id: ControlListModel.STOP_BUTTON, file: "StopButton.qml", label: VLCIcons.stop, text: qsTr("Stop") },
        { id: ControlListModel.OPEN_BUTTON, file: "OpenButton.qml", label: VLCIcons.eject, text: qsTr("Open") },
        { id: ControlListModel.PREVIOUS_BUTTON, file: "PreviousButton.qml", label: VLCIcons.previous, text: qsTr("Previous") },
        { id: ControlListModel.NEXT_BUTTON, file: "NextButton.qml", label: VLCIcons.next, text: qsTr("Next") },
        { id: ControlListModel.SLOWER_BUTTON, file: "SlowerButton.qml", label: VLCIcons.slower, text: qsTr("Slower") },
        { id: ControlListModel.FASTER_BUTTON, file: "FasterButton.qml", label: VLCIcons.faster, text: qsTr("Faster") },
        { id: ControlListModel.FULLSCREEN_BUTTON, file: "FullscreenButton.qml", label: VLCIcons.fullscreen, text: qsTr("Fullscreen") },
        { id: ControlListModel.EXTENDED_BUTTON, file: "ExtendedSettingsButton.qml", label: VLCIcons.effect_filter, text: qsTr("Extended panel") },
        { id: ControlListModel.PLAYLIST_BUTTON, file: "PlaylistButton.qml", label: VLCIcons.playlist, text: qsTr("Play Queue") },
        { id: ControlListModel.SNAPSHOT_BUTTON, file: "SnapshotButton.qml", label: VLCIcons.snapshot, text: qsTr("Snapshot") },
        { id: ControlListModel.RECORD_BUTTON, file: "RecordButton.qml", label: VLCIcons.record, text: qsTr("Record") },
        { id: ControlListModel.ATOB_BUTTON, file: "AtoBButton.qml", label: VLCIcons.atob, text: qsTr("A-B Loop") },
        { id: ControlListModel.FRAME_PREV_BUTTON, file: "FrameNextButton.qml", label: VLCIcons.next_frame, text: qsTr("Next Frame") },
        { id: ControlListModel.FRAME_NEXT_BUTTON, file: "FramePrevButton.qml", label: VLCIcons.previous_frame, text: qsTr("Previous Frame") },
        { id: ControlListModel.REVERSE_BUTTON, file: "ReverseButton.qml", label: VLCIcons.play_reverse, text: qsTr("Trickplay Reverse") },
        { id: ControlListModel.SKIP_BACK_BUTTON, file: "SkipBackButton.qml", label: VLCIcons.skip_back, text: qsTr("Step backward") },
        { id: ControlListModel.SKIP_FW_BUTTON, file: "SkipForwardButton.qml", label: VLCIcons.skip_for, text: qsTr("Step forward") },
        { id: ControlListModel.QUIT_BUTTON, file: "QuitButton.qml", label: VLCIcons.clear, text: qsTr("Quit") },
        { id: ControlListModel.RANDOM_BUTTON, file: "RandomButton.qml", label: VLCIcons.shuffle, text: qsTr("Random") },
        { id: ControlListModel.LOOP_BUTTON, file: "LoopButton.qml", label: VLCIcons.repeat_all, text: qsTr("Loop") },
        { id: ControlListModel.INFO_BUTTON, file: "InfoButton.qml", label: VLCIcons.info, text: qsTr("Information") },
        { id: ControlListModel.LANG_BUTTON, file: "LangButton.qml", label: VLCIcons.audiosub, text: qsTr("Open subtitles") },
        { id: ControlListModel.BOOKMARK_BUTTON, file: "BookmarkButton.qml", label: VLCIcons.bookmark, text: qsTr("Bookmark Button") },
        { id: ControlListModel.CHAPTER_PREVIOUS_BUTTON, file: "ChapterPreviousButton.qml", label: VLCIcons.dvd_prev, text: qsTr("Previous chapter") },
        { id: ControlListModel.CHAPTER_NEXT_BUTTON, file: "ChapterNextButton.qml", label: VLCIcons.dvd_next, text: qsTr("Next chapter") },
        { id: ControlListModel.VOLUME, file: "VolumeWidget.qml", label: VLCIcons.volume_high, text: qsTr("Volume Widget") },
        { id: ControlListModel.NAVIGATION_BOX, file: "NavigationBoxButton.qml", label: VLCIcons.ic_fluent_arrow_move, text: qsTr("Navigation Box") },
        { id: ControlListModel.NAVIGATION_BUTTONS, file: "NavigationWidget.qml", label: VLCIcons.dvd_menu, text: qsTr("Navigation") },
        { id: ControlListModel.DVD_MENUS_BUTTON, file: "DvdMenuButton.qml", label: VLCIcons.dvd_menu, text: qsTr("DVD menus") },
        { id: ControlListModel.PROGRAM_BUTTON, file: "ProgramButton.qml", label: VLCIcons.tv, text: qsTr("Program Button") },
        { id: ControlListModel.TELETEXT_BUTTONS, file: "TeletextButton.qml", label: VLCIcons.tvtelx, text: qsTr("Teletext") },
        { id: ControlListModel.RENDERER_BUTTON, file: "RendererButton.qml", label: VLCIcons.renderer, text: qsTr("Renderer Button") },
        { id: ControlListModel.ASPECT_RATIO_COMBOBOX, file: "AspectRatioWidget.qml", label: VLCIcons.aspect_ratio, text: qsTr("Aspect Ratio") },
        { id: ControlListModel.WIDGET_SPACER, file: "SpacerWidget.qml", label: VLCIcons.space, text: qsTr("Spacer") },
        { id: ControlListModel.WIDGET_SPACER_EXTEND, file: "ExpandingSpacerWidget.qml", label: VLCIcons.space, text: qsTr("Expanding Spacer") },
        { id: ControlListModel.PLAYER_SWITCH_BUTTON, file: "PlayerSwitchButton.qml", label: VLCIcons.fullscreen, text: qsTr("Switch Player") },
        { id: ControlListModel.ARTWORK_INFO, file: "ArtworkInfoWidget.qml", label: VLCIcons.info, text: qsTr("Artwork Info") },
        { id: ControlListModel.PLAYBACK_SPEED_BUTTON, file: "PlaybackSpeedButton.qml", label: "1x", text: qsTr("Playback Speed") },
        { id: ControlListModel.HIGH_RESOLUTION_TIME_WIDGET, file: "HighResolutionTimeWidget.qml", label: VLCIcons.time, text: qsTr("High Resolution Time") },
        // redesign controls (design/SPEC.md "Customize Player")
        { id: ControlListModel.AUDIO_SETTINGS_BUTTON, file: "AudioSettingsButton.qml", label: VLCIcons.visualization, text: qsTr("Audio") },
        { id: ControlListModel.SUBTITLE_BUTTON, file: "SubtitleButton.qml", label: VLCIcons.audiosub, text: qsTr("Subtitles") },
        { id: ControlListModel.PLAYBACK_SETTINGS_BUTTON, file: "PlaybackSettingsButton.qml", label: VLCIcons.settings, text: qsTr("Playback Settings") },
        { id: ControlListModel.SKIP_FW_10_BUTTON, file: "SkipForward10Button.qml", label: VLCIcons.skip_for, text: qsTr("Forward 10s") },
        { id: ControlListModel.SKIP_BACK_10_BUTTON, file: "SkipBack10Button.qml", label: VLCIcons.skip_back, text: qsTr("Backward 10s") },
        { id: ControlListModel.SKIP_FW_15_BUTTON, file: "SkipForward15Button.qml", label: VLCIcons.skip_for, text: qsTr("Forward 15s") },
        { id: ControlListModel.SKIP_BACK_15_BUTTON, file: "SkipBack15Button.qml", label: VLCIcons.skip_back, text: qsTr("Backward 15s") },
        { id: ControlListModel.PIP_BUTTON, file: "PipButton.qml", label: VLCIcons.window_restore, text: qsTr("Picture in Picture") },
        { id: ControlListModel.HDR_BUTTON, file: "HdrButton.qml", label: VLCIcons.tv, text: qsTr("HDR") },
        { id: ControlListModel.ZOOM_BUTTON, file: "ZoomButton.qml", label: VLCIcons.search, text: qsTr("Zoom") },
        { id: ControlListModel.SIDEBAR_BUTTON, file: "SidebarButton.qml", label: VLCIcons.panel_left, text: qsTr("Right Sidebar") },
        { id: ControlListModel.SETTINGS_BUTTON, file: "SettingsButton.qml", label: VLCIcons.settings, text: qsTr("VLC Settings") },
        { id: ControlListModel.HOME_BUTTON, file: "HomeButton.qml", label: VLCIcons.home, text: qsTr("Go Home") },
        { id: ControlListModel.REPLAY_BUTTON, file: "ReplayButton.qml", label: VLCIcons.history, text: qsTr("Replay") },
        { id: ControlListModel.CHAPTERS_BUTTON, file: "ChaptersButton.qml", label: VLCIcons.list, text: qsTr("Chapters") },
        { id: ControlListModel.FAVORITE_BUTTON, file: "FavoriteButton.qml", label: VLCIcons.active_indicator, text: qsTr("Favorite") },
        { id: ControlListModel.ADD_BOOKMARK_BUTTON, file: "AddBookmarkButton.qml", label: VLCIcons.bookmark, text: qsTr("Bookmark") },
        { id: ControlListModel.PLAYLISTS_BUTTON, file: "PlaylistsButton.qml", label: VLCIcons.playlist, text: qsTr("Playlists") },
        { id: ControlListModel.WIDGET_DIVIDER, file: "DividerWidget.qml", label: "|", text: qsTr("Divider") },
        { id: ControlListModel.THUMBNAIL_WIDGET, file: "ThumbnailWidget.qml", label: VLCIcons.album_cover, text: qsTr("Thumbnail") },
        { id: ControlListModel.FILE_NAME_WIDGET, file: "FileNameWidget.qml", label: VLCIcons.info, text: qsTr("File Name") },
        { id: ControlListModel.ARTIST_NAME_WIDGET, file: "ArtistNameWidget.qml", label: VLCIcons.info, text: qsTr("Artist Name") },
        { id: ControlListModel.FOLDER_NAME_WIDGET, file: "FolderNameWidget.qml", label: VLCIcons.info, text: qsTr("Folder Name") },
        { id: ControlListModel.PLAYLIST_NAME_WIDGET, file: "PlaylistNameWidget.qml", label: VLCIcons.info, text: qsTr("Playlist Name") }
    ]

    // items of the "Customize Player" palette, in the design order
    // (design/SPEC.md 2.1 "Player - customize"), mapped to control ids
    readonly property var customizePalette: [
        ControlListModel.WIDGET_SPACER_EXTEND,      // Spacer
        ControlListModel.WIDGET_DIVIDER,            // Divider
        ControlListModel.PLAYBACK_SPEED_BUTTON,     // Playback Speed
        ControlListModel.SKIP_FW_10_BUTTON,         // Forward 10s
        ControlListModel.SKIP_BACK_10_BUTTON,       // Backward 10s
        ControlListModel.SKIP_FW_15_BUTTON,         // Forward 15s
        ControlListModel.SKIP_BACK_15_BUTTON,       // Backward 15s
        ControlListModel.STOP_BUTTON,               // Stop
        ControlListModel.LOOP_BUTTON,               // Repeat
        ControlListModel.RANDOM_BUTTON,             // Shuffle
        ControlListModel.RECORD_BUTTON,             // Record
        ControlListModel.SNAPSHOT_BUTTON,           // Snapshot
        ControlListModel.PIP_BUTTON,                // Picture in Picture
        ControlListModel.HDR_BUTTON,                // HDR
        ControlListModel.ZOOM_BUTTON,               // Zoom
        ControlListModel.SIDEBAR_BUTTON,            // Right Sidebar
        ControlListModel.QUIT_BUTTON,               // Quit VLC
        ControlListModel.SETTINGS_BUTTON,           // VLC Settings
        ControlListModel.HOME_BUTTON,               // Go Home
        ControlListModel.THUMBNAIL_WIDGET,          // Thumbnail
        ControlListModel.FILE_NAME_WIDGET,          // File Name
        ControlListModel.ARTIST_NAME_WIDGET,        // Artist Name
        ControlListModel.FOLDER_NAME_WIDGET,        // Folder Name
        ControlListModel.PLAYLIST_NAME_WIDGET,      // Playlist Name
        ControlListModel.INFO_BUTTON,               // Properties
        ControlListModel.REPLAY_BUTTON,             // Replay
        ControlListModel.CHAPTERS_BUTTON,           // Chapters
        ControlListModel.FAVORITE_BUTTON,           // Favorite
        ControlListModel.ADD_BOOKMARK_BUTTON,       // Bookmark
        ControlListModel.BOOKMARK_BUTTON,           // Bookmarks
        ControlListModel.PLAYLISTS_BUTTON           // Playlists
    ]

    // label of a control in the "Customize Player" palette
    readonly property var customizeLabels: ({
        [ControlListModel.WIDGET_SPACER_EXTEND]: qsTr("Spacer"),
        [ControlListModel.LOOP_BUTTON]: qsTr("Repeat"),
        [ControlListModel.RANDOM_BUTTON]: qsTr("Shuffle"),
        [ControlListModel.QUIT_BUTTON]: qsTr("Quit VLC"),
        [ControlListModel.INFO_BUTTON]: qsTr("Properties"),
        [ControlListModel.BOOKMARK_BUTTON]: qsTr("Bookmarks")
    })

    function control(id) {
        const entry = controlList.find( function(e) { return ( e.id === id ) } )

        if (entry === undefined) {
            console.warn("control delegate id " + id +  " doesn't exist")
            return { source: controlPath + "Fallback.qml" }
        }

        entry.source = controlPath + entry.file

        return entry
    }
}
