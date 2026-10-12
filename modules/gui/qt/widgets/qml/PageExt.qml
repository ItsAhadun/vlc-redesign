/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
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
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Menus
import VLC.Util
import VLC.Dialogs
import VLC.Widgets as Widgets

T.Page {
    id: root

    //path of the current page loader
    property var pagePrefix: []

    //note that T.Page introduce an intermediate Item, so to access our delegate,
    //we need to use contentChildren[0] rather than contentItem
    readonly property Item _firstChild: contentChildren[0] ?? null

    //indicates whether the subview support grid/list mode
    property bool hasGridListMode: _firstChild?.hasGridListMode ?? false

    property bool isSearchable: _firstChild?.isSearchable ?? false

    property var sortModel: _firstChild?.sortModel ?? null

    //property is *not* readOnly, a PageLoader may define a localMenuDelegate common for its subviews (music, video)
    property SortMenu sortMenu: null

    property int displayMarginBeginning: 0
    property int displayMarginEnd: 0

    property bool enableBeginningFade: true
    property bool enableEndFade: true

    readonly property SearchCtx search: _searchCtx
    readonly property SortCtx sort: _sortCtx


    SearchCtx {
        id: _searchCtx
        available: root.isSearchable
    }

    SortCtx {
        id: _sortCtx

        readonly property string _sortCriteriaKey: ["sortCriteria", ...root.pagePrefix].join("/")
        readonly property string _sortOrderKey:  ["sortOrder", ...root.pagePrefix].join("/")

        available: Helpers.isArray(root.sortModel) && (root.sortModel).length > 0
        model: root.sortModel

        //save & restore setting of the page
        Component.onCompleted: {
            const criteria = MainCtx.settingValue(_sortCriteriaKey, undefined)
            if (criteria !== undefined)
                _sortCtx.criteria = criteria

            const order = MainCtx.settingValue(_sortOrderKey, undefined)
            if (order !== undefined)
                _sortCtx.order = parseInt(order)
        }

        Component.onDestruction: {
            MainCtx.setSettingValue(_sortCriteriaKey, _sortCtx.criteria)
            MainCtx.setSettingValue(_sortOrderKey, _sortCtx.order)
        }
    }

    Binding {
        target: MainCtx
        property: "hasGridListMode";
        value: root.hasGridListMode
    }

    on_FirstChildChanged: {
        if (!_firstChild)
            return
        _firstChild.Navigation.parentItem = root
        _firstChild.Navigation.upItem = root.header
    }

    function positionContentAtBeginning() {
        _firstChild?.positionContentAtBeginning?.()
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding
                             + (implicitHeaderHeight > 0 ? implicitHeaderHeight + spacing : 0)
                             + (implicitFooterHeight > 0 ? implicitFooterHeight + spacing : 0))

    // Header (design/SPEC.md 2.1): breadcrumb + count, sort, view, search, "+", "..."

    // [{ text, path, siblings }], computed from the page loaders by default
    property var breadcrumbModel: _defaultBreadcrumb()

    // -1 hides the count
    property int itemCount: {
        const child = root._firstChild
        if (typeof child?.count === "number")
            return child.count
        if (typeof child?.model?.count === "number")
            return child.model.count
        return -1
    }

    // function() or null, the "+" button: adds a folder to the media library by default
    property var addAction: MainCtx.mediaLibraryAvailable ? function() { DialogsProvider.addMediaLibraryFolder() }
                                                          : null

    // "..." menu entries ([{ text, action, visible }])
    property var moreActions: _defaultMoreActions()

    function _pageLoaders() {
        const loaders = []
        for (let item = root.parent; item; item = item.parent) {
            if (item.pageModel !== undefined && item.pageName !== undefined && item.pagePrefix !== undefined)
                loaders.unshift(item)
        }
        return loaders
    }

    function _defaultBreadcrumb() {
        // re-evaluate on navigation
        void History.viewPath
        void History.viewProp

        const crumbs = []
        const loaders = _pageLoaders()

        for (let i = 0; i < loaders.length; ++i) {
            const loader = loaders[i]
            const entries = loader.pageModel ?? []
            const entry = entries.find((e) => e.name === loader.pageName)
            if (!entry || !entry.displayText || entry.breadcrumb === false)
                continue

            const siblings = (i === 0) ? [] : entries.filter((e) => !!e.displayText && e.breadcrumb !== false)
                                                    .map((e) => ({ text: e.displayText,
                                                                   path: [...loader.pagePrefix, e.name] }))

            crumbs.push({
                text: entry.displayText,
                path: [...loader.pagePrefix, loader.pageName],
                siblings: siblings
            })
        }

        // drill down pages (a group, a folder, an album, a playlist...)
        const leafLoader = loaders[loaders.length - 1]
        if (leafLoader) {
            const leafEntry = (leafLoader.pageModel ?? []).find((e) => e.name === leafLoader.pageName)
            if (leafEntry && !leafEntry.default && !leafEntry.displayText) {
                const title = History.viewProp?.title ?? root.title
                if (title && (crumbs.length === 0 || crumbs[crumbs.length - 1].text !== title))
                    crumbs.push({ text: title, path: [...leafLoader.pagePrefix, leafLoader.pageName], siblings: [] })
            }
        }

        if (crumbs.length === 0 && root.title)
            crumbs.push({ text: root.title, path: root.pagePrefix, siblings: [] })

        return crumbs
    }

    function _defaultMoreActions() {
        const model = _firstChild?.model
        const isMLModel = !!model && (typeof model.getData === "function") && !!model.ml

        function _withAllIds(callback) {
            const indexes = []
            for (let i = 0; i < model.count; ++i)
                indexes.push(model.index(i, 0))
            model.getData(indexes, (data) => {
                const ids = data.map((d) => d.id).filter((id) => id !== undefined)
                if (ids.length > 0)
                    callback(ids)
            })
        }

        return [{
            text: qsTr("Play All"),
            visible: isMLModel && model.count > 0,
            action: () => _withAllIds((ids) => model.ml.addAndPlay(ids))
        }, {
            text: qsTr("Enqueue All"),
            visible: isMLModel && model.count > 0,
            action: () => _withAllIds((ids) => model.ml.addToPlaylist(ids))
        }, {
            text: qsTr("Refresh Media Library"),
            visible: MainCtx.mediaLibraryAvailable,
            action: () => MainCtx.mediaLibrary.reload()
        }]
    }

    header: Widgets.LibraryHeaderBar {
        leftPadding: VLCStyle.layout_left_margin + root.leftPadding
        rightPadding: VLCStyle.layout_right_margin + root.rightPadding

        breadcrumbModel: root.breadcrumbModel
        itemCount: root.itemCount

        sort: _sortCtx
        search: _searchCtx
        sortMenu: root.sortMenu

        hasGridListMode: root.hasGridListMode

        addAction: root.addAction
        moreActions: root.moreActions

        Navigation.parentItem: root
        Navigation.downAction: function() {
            if (typeof root.setCurrentItemFocus === "function")
                root.setCurrentItemFocus(Qt.TabFocusReason)
            else if (typeof root._firstChild?.setCurrentItemFocus === "function")
             root._firstChild.setCurrentItemFocus(Qt.TabFocusReason)
            else if (root._firstChild)
                root._firstChild.forceActiveFocus(Qt.TabFocusReason)
        }
    }
}
