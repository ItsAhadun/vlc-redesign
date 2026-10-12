/*****************************************************************************
 * settingsbackend.hpp : bridge between the QML settings window and the
 *                       VLC configuration
 *****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#ifndef VLC_QT_SETTINGSBACKEND_HPP
#define VLC_QT_SETTINGSBACKEND_HPP

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <QObject>
#include <QVariant>
#include <QTimer>

#include "qt.hpp"

/**
 * SettingsBackend reads and writes VLC options (vlcrc) for the QML settings
 * window ("VLC.Dialogs" singleton `SettingsBackend`).
 *
 * Values are written with config_Put*() as soon as a control changes and the
 * configuration file is saved shortly after (debounced) and when the window
 * closes, so nothing is lost if VLC exits with the window open.
 *
 * QML bindings that read values should depend on `revision` so that they are
 * re-evaluated after any write or reset:
 *     checked: { SettingsBackend.revision; return SettingsBackend.value("osd") }
 *
 * Other parts of the interface can use it as a read accessor for the new
 * `qt-*` options too (e.g. `SettingsBackend.value("qt-video-dblclick-action")`).
 */
class SettingsBackend : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged FINAL)
    Q_PROPERTY(bool languageEditable READ languageEditable CONSTANT FINAL)
    Q_PROPERTY(bool hasMediaLibrary READ hasMediaLibrary CONSTANT FINAL)

public:
    explicit SettingsBackend(qt_intf_t *intf, QObject *parent = nullptr);
    ~SettingsBackend() override;

    int revision() const { return m_revision; }
    bool languageEditable() const;
    bool hasMediaLibrary() const;

    /* generic option access */
    Q_INVOKABLE bool exists(const QString &key) const;
    Q_INVOKABLE QVariant value(const QString &key) const;
    Q_INVOKABLE QVariant defaultValue(const QString &key) const;
    Q_INVOKABLE void setValue(const QString &key, const QVariant &value);
    Q_INVOKABLE void resetValue(const QString &key);
    /// option long help, translated (used for the (i) tooltips)
    Q_INVOKABLE QString longText(const QString &key) const;
    /// option choices: list of { value, text }
    Q_INVOKABLE QVariantList choices(const QString &key) const;
    /// option range: { min, max } (empty when the option has no range)
    Q_INVOKABLE QVariantMap range(const QString &key) const;
    Q_INVOKABLE bool moduleExists(const QString &name) const;

    /* options holding a ':' separated module list (audio-filter, control...) */
    Q_INVOKABLE bool listHas(const QString &key, const QString &item) const;
    Q_INVOKABLE void setListItem(const QString &key, const QString &item, bool present);

    /* settings that are not vlcrc options */
    Q_INVOKABLE QVariantList languages() const;
    Q_INVOKABLE QString language() const;
    Q_INVOKABLE void setLanguage(const QString &iso);
    Q_INVOKABLE int colorSchemeIndex() const;
    Q_INVOKABLE void setColorSchemeIndex(int index);
    Q_INVOKABLE QVariantList screens() const;
    /// optical drives, list of { value: device path, text }
    Q_INVOKABLE QVariantList opticalDrives() const;

    /* actions */
    Q_INVOKABLE QString browseFile(const QString &title, const QString &current) const;
    Q_INVOKABLE QString browseDirectory(const QString &title, const QString &current) const;
    Q_INVOKABLE void openConfigFolder() const;
    Q_INVOKABLE void resetAll();
    Q_INVOKABLE void resetHotkeys();
    Q_INVOKABLE void clearHistory();
    Q_INVOKABLE void openClassicPreferences() const;
    Q_INVOKABLE void openHotkeysEditor() const;
    Q_INVOKABLE void openAddonsManager() const;
    Q_INVOKABLE void save();

signals:
    void revisionChanged();
    /// emitted when a value changed, by the window or by a reset
    void valueChanged(const QString &key);

private:
    void bump(const QString &key);
    void scheduleSave();

    qt_intf_t *m_intf = nullptr;
    int m_revision = 0;
    QTimer m_saveTimer;
};

#endif // VLC_QT_SETTINGSBACKEND_HPP
