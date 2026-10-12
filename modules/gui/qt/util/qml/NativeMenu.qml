
/*****************************************************************************
 * Copyright (C) 2022 VLC authors and VideoLAN
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
import QtQml

import VLC.MainInterface
import VLC.Menus

// @brief - a class that can be used to create native menus with support
// to asyncronously retreive data from MLBaseModel like model

QtObject {
    id: root

    /**
      actions - list of action to show

      each action is an Object and contains following keys
        "text" - (string) display text of the action

        "icon" - (string) (optional) VLCIcons glyph shown before the text

        "action" - (function(dataList, options, indexes)) a function that will be called when action is selected

        "visible" - (Boolean or function(dataList,options, indexes) -> Boolean) (optional) a boolean value or function which
                    controls whether the action is shown in the menu following 'popup' call

       e.g see MLContextMenu.qml
    **/

    property var actions: []

    // the redesign QML menu (Widgets.MenuExt) is used when available, the
    // native menu otherwise
    readonly property bool visible: (_qmlMenu?.visible ?? false) || menu.visible

    readonly property int currentRequest: _currentRequest

    signal requestData(var requestID, var indexes)


    property var _options: null

    property var _indexes: []

    property var _dataList: null

    property int _currentRequest: 0

    property var _effectiveActions: null

    property point _popupPoint

    property var _qmlMenu: null
    property var _qmlItems: []

    // requests data for '_indexes' and shows popup menu
    // with 'NativeMenu::actions' based on '_options'
    // returns unique request id
    function popup(_indexes, point, _options) {
        root._options = _options
        root._indexes = _indexes
        _dataList = null
        _popupPoint = point

        const requestID = ++_currentRequest
        requestData(requestID, _indexes)
        return requestID
    }

    function setData(id, data) {
        if (_currentRequest !== id)
            return;

        _dataList = data

        const textStrings = []
        _effectiveActions = []
        for (let i in actions) {
            const action = actions[i]

            if (!action.hasOwnProperty("visible")
                    || (typeof action.visible === "boolean" && action.visible)
                    || (typeof action.visible === "function" && action.visible(_dataList, _options, _indexes))) {
                _effectiveActions.push(action)
                textStrings.push(action.text)
            }
        }

        if (!_popupQmlMenu())
            menu.popup(_popupPoint, textStrings)
    }

    function _executeAction(index) {
        const action = root._effectiveActions[index]
        action.action(_dataList, _options, _indexes)
    }

    // design/SPEC.md 3.9 context menus
    function _popupQmlMenu() {
        const window = MainCtx.intfMainWindow
        const parentItem = window?.contentItem ?? null
        if (!parentItem)
            return false

        if (!_qmlMenu) {
            const menuComponent = Qt.createComponent("qrc:///qt/qml/VLC/Widgets/MenuExt.qml")
            if (menuComponent.status !== Component.Ready) {
                console.warn("NativeMenu: unable to create the menu:", menuComponent.errorString())
                return false
            }
            _qmlMenu = menuComponent.createObject(parentItem)
            if (!_qmlMenu)
                return false
        }

        const itemComponent = Qt.createComponent("qrc:///qt/qml/VLC/Widgets/MenuItemExt.qml")
        if (itemComponent.status !== Component.Ready) {
            console.warn("NativeMenu: unable to create the menu items:", itemComponent.errorString())
            return false
        }

        for (const item of _qmlItems) {
            _qmlMenu.removeItem(item)
            item.destroy()
        }
        _qmlItems = []

        for (let i = 0; i < _effectiveActions.length; ++i) {
            const action = _effectiveActions[i]
            const item = itemComponent.createObject(null, {
                "text": action.text,
                "iconText": action.icon ?? ""
            })
            const actionIndex = i
            item.triggered.connect(() => root._executeAction(actionIndex))
            _qmlMenu.addItem(item)
            _qmlItems.push(item)
        }

        const position = parentItem.mapFromGlobal(_popupPoint.x, _popupPoint.y)
        _qmlMenu.parent = parentItem
        _qmlMenu.popup(position.x, position.y)
        return true
    }

    readonly property StringListMenu _menu: StringListMenu {
        id: menu

        ctx: MainCtx

        onSelected: (index, _) => {
            root._executeAction(index)
        }
    }
}
