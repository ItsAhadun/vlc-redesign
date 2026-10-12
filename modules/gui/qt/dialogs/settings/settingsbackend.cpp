/*****************************************************************************
 * settingsbackend.cpp : bridge between the QML settings window and the
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

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "settingsbackend.hpp"

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>
#include <vlc_media_library.h>

#include <algorithm>

#include <QDesktopServices>
#include <QDir>
#include <QFileDialog>
#include <QGuiApplication>
#include <QScreen>
#include <QSettings>
#include <QUrl>

#ifdef _WIN32
# include <windows.h>
#endif

#include "dialogs/dialogs_provider.hpp"
#include "dialogs/preferences/simple_preferences.hpp"
#include "maininterface/mainctx.hpp"
#include "medialibrary/medialib.hpp"
#include "util/color_scheme_model.hpp"

namespace {

constexpr int SAVE_DELAY_MS = 800;

/* options read by MainCtx::loadPrefs(), applied live with reloadPrefs() */
bool isMainCtxPref(const QString &key)
{
    static const char *const keys[] = {
        "qt-minimal-view", "qt-bgcone", "video-on-top", "qt-menubar",
        "qt-titlebar", "qt-smooth-scrolling", "qt-max-volume",
        "qt-pin-controls", "qt-fs-opacity", "qt-safe-area",
        "mouse-hide-timeout",
    };
    for (const char *k : keys)
        if (key == QLatin1String(k))
            return true;
    return false;
}

QStringList splitList(const QString &value)
{
    QStringList list;
    for (const QString &s : value.split(QLatin1Char(':'), Qt::SkipEmptyParts))
    {
        const QString t = s.trimmed();
        if (!t.isEmpty())
            list.append(t);
    }
    return list;
}

} // namespace

SettingsBackend::SettingsBackend(qt_intf_t *intf, QObject *parent)
    : QObject(parent)
    , m_intf(intf)
{
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(SAVE_DELAY_MS);
    connect(&m_saveTimer, &QTimer::timeout, this, &SettingsBackend::save);

    /* the classic preferences may change anything: refresh on close */
    if (DialogsProvider *dp = DialogsProvider::getInstance())
    {
        connect(dp, &DialogsProvider::classicPrefsDialogVisibleChanged, this, [this]() {
            bump(QString());
        });
    }
}

SettingsBackend::~SettingsBackend()
{
    if (m_saveTimer.isActive())
        save();
}

bool SettingsBackend::languageEditable() const
{
    return SPrefsPanel::languageIsEditable();
}

bool SettingsBackend::hasMediaLibrary() const
{
    return m_intf->p_mi && m_intf->p_mi->getMediaLibrary();
}

bool SettingsBackend::exists(const QString &key) const
{
    const QByteArray name = key.toUtf8();
    if (config_GetType(name.constData()) == 0)
        return false;
    /* obsolete options (add_obsolete_*) are kept without any text */
    const module_config_t *item = config_FindConfig(name.constData());
    return item && item->psz_text;
}

QVariant SettingsBackend::value(const QString &key) const
{
    const QByteArray name = key.toUtf8();
    switch (config_GetType(name.constData()))
    {
    case VLC_VAR_BOOL:
        return QVariant(config_GetInt(name.constData()) != 0);
    case VLC_VAR_INTEGER:
        return QVariant(qlonglong(config_GetInt(name.constData())));
    case VLC_VAR_FLOAT:
        return QVariant(double(config_GetFloat(name.constData())));
    case VLC_VAR_STRING:
    {
        char *psz = config_GetPsz(name.constData());
        QString s = psz ? qfu(psz) : QString();
        free(psz);
        return QVariant(s);
    }
    default:
        return {};
    }
}

QVariant SettingsBackend::defaultValue(const QString &key) const
{
    const QByteArray name = key.toUtf8();
    const module_config_t *item = config_FindConfig(name.constData());
    if (!item)
        return {};
    switch (config_GetType(name.constData()))
    {
    case VLC_VAR_BOOL:
        return QVariant(item->orig.i != 0);
    case VLC_VAR_INTEGER:
        return QVariant(qlonglong(item->orig.i));
    case VLC_VAR_FLOAT:
        return QVariant(double(item->orig.f));
    case VLC_VAR_STRING:
        return QVariant(item->orig.psz ? qfu(item->orig.psz) : QString());
    default:
        return {};
    }
}

void SettingsBackend::setValue(const QString &key, const QVariant &value)
{
    const QByteArray name = key.toUtf8();
    switch (config_GetType(name.constData()))
    {
    case VLC_VAR_BOOL:
        config_PutInt(name.constData(), value.toBool() ? 1 : 0);
        break;
    case VLC_VAR_INTEGER:
    {
        const module_config_t *item = config_FindConfig(name.constData());
        int64_t v = value.toLongLong();
        /* config_PutInt clamps too, but keep the value we report coherent */
        if (item && item->min.i < item->max.i)
            v = std::clamp<int64_t>(v, item->min.i, item->max.i);
        config_PutInt(name.constData(), v);
        break;
    }
    case VLC_VAR_FLOAT:
        config_PutFloat(name.constData(), value.toFloat());
        break;
    case VLC_VAR_STRING:
    {
        const QByteArray v = value.toString().toUtf8();
        config_PutPsz(name.constData(), v.isEmpty() ? nullptr : v.constData());
        break;
    }
    default:
        msg_Warn(m_intf, "settings: unknown option '%s'", name.constData());
        return;
    }

    if (isMainCtxPref(key) && m_intf->p_mi)
        m_intf->p_mi->reloadPrefs();

    bump(key);
    scheduleSave();
}

void SettingsBackend::resetValue(const QString &key)
{
    setValue(key, defaultValue(key));
}

QString SettingsBackend::longText(const QString &key) const
{
    const module_config_t *item = config_FindConfig(qtu(key));
    if (!item)
        return {};
    if (item->psz_longtext && *item->psz_longtext)
        return qfut(item->psz_longtext);
    if (item->psz_text)
        return qfut(item->psz_text);
    return {};
}

QVariantList SettingsBackend::choices(const QString &key) const
{
    QVariantList list;
    const QByteArray name = key.toUtf8();
    const int type = config_GetType(name.constData());

    if (type == VLC_VAR_STRING)
    {
        char **values = nullptr, **texts = nullptr;
        const ssize_t count = config_GetPszChoices(name.constData(), &values, &texts);
        for (ssize_t i = 0; i < count; i++)
        {
            if (values[i] && texts[i])
                list.append(QVariantMap{ { "value", qfu(values[i]) },
                                         { "text", qfut(texts[i]) } });
            free(values[i]);
            free(texts[i]);
        }
        free(values);
        free(texts);
    }
    else if (type == VLC_VAR_INTEGER)
    {
        int64_t *values = nullptr;
        char **texts = nullptr;
        const ssize_t count = config_GetIntChoices(name.constData(), &values, &texts);
        for (ssize_t i = 0; i < count; i++)
        {
            list.append(QVariantMap{ { "value", qlonglong(values[i]) },
                                     { "text", texts[i] ? qfut(texts[i]) : QString::number(values[i]) } });
            free(texts[i]);
        }
        free(values);
        free(texts);
    }
    return list;
}

QVariantMap SettingsBackend::range(const QString &key) const
{
    const QByteArray name = key.toUtf8();
    const module_config_t *item = config_FindConfig(name.constData());
    if (!item)
        return {};
    switch (config_GetType(name.constData()))
    {
    case VLC_VAR_INTEGER:
        if (item->min.i < item->max.i)
            return { { "min", qlonglong(item->min.i) }, { "max", qlonglong(item->max.i) } };
        break;
    case VLC_VAR_FLOAT:
        if (item->min.f < item->max.f)
            return { { "min", double(item->min.f) }, { "max", double(item->max.f) } };
        break;
    default:
        break;
    }
    return {};
}

bool SettingsBackend::moduleExists(const QString &name) const
{
    return module_exists(qtu(name));
}

bool SettingsBackend::listHas(const QString &key, const QString &item) const
{
    return splitList(value(key).toString()).contains(item);
}

void SettingsBackend::setListItem(const QString &key, const QString &item, bool present)
{
    QStringList list = splitList(value(key).toString());
    if (present == list.contains(item))
        return;
    if (present)
        list.append(item);
    else
        list.removeAll(item);
    setValue(key, list.join(QLatin1Char(':')));
}

QVariantList SettingsBackend::languages() const
{
    QVariantList list;
    for (const SPrefsPanel::Language &lang : SPrefsPanel::languages())
        list.append(QVariantMap{ { "value", lang.iso }, { "text", lang.name } });
    return list;
}

QString SettingsBackend::language() const
{
    return SPrefsPanel::currentLanguage();
}

void SettingsBackend::setLanguage(const QString &iso)
{
    SPrefsPanel::setCurrentLanguage(iso);
    bump(QStringLiteral("language"));
}

int SettingsBackend::colorSchemeIndex() const
{
    if (!m_intf->p_mi || !m_intf->p_mi->getColorScheme())
        return 0;
    return m_intf->p_mi->getColorScheme()->currentIndex();
}

void SettingsBackend::setColorSchemeIndex(int index)
{
    if (!m_intf->p_mi || !m_intf->p_mi->getColorScheme())
        return;
    m_intf->p_mi->getColorScheme()->setCurrentIndex(index);
    /* MainCtx saves it on exit; save now too so it survives a crash */
    if (m_intf->mainSettings)
        m_intf->mainSettings->setValue(QStringLiteral("MainWindow/color-scheme-index"), index);
    bump(QStringLiteral("color-scheme"));
}

QVariantList SettingsBackend::screens() const
{
    QVariantList list;
    list.append(QVariantMap{ { "value", -1 }, { "text", qtr("Current screen") } });
    const QList<QScreen *> screens = QGuiApplication::screens();
    for (int i = 0; i < screens.size(); ++i)
    {
        const QScreen *screen = screens.at(i);
        const QString name = screen->model().isEmpty() ? screen->name() : screen->model();
        list.append(QVariantMap{ { "value", i },
                                 { "text", qtr("Screen %1 (%2)").arg(i + 1).arg(name) } });
    }
    return list;
}

QVariantList SettingsBackend::opticalDrives() const
{
    QVariantList list;
#ifdef _WIN32
    for (const QFileInfo &drive : QDir::drives())
    {
        const QString path = QDir::toNativeSeparators(drive.absolutePath());
        if (GetDriveTypeW(reinterpret_cast<LPCWSTR>(path.utf16())) == DRIVE_CDROM)
        {
            const QString dev = path.left(2); // "D:"
            list.append(QVariantMap{ { "value", dev }, { "text", dev } });
        }
    }
#else
    const QDir dev(QStringLiteral("/dev"));
    const QStringList names = dev.entryList({ QStringLiteral("sr[0-9]*"), QStringLiteral("cdrom*"),
                                              QStringLiteral("dvd*") },
                                            QDir::System | QDir::Files | QDir::NoDotAndDotDot);
    for (const QString &name : names)
    {
        const QString path = dev.absoluteFilePath(name);
        list.append(QVariantMap{ { "value", path }, { "text", path } });
    }
#endif
    return list;
}

QString SettingsBackend::browseFile(const QString &title, const QString &current) const
{
    const QString dir = current.isEmpty() ? QString() : QFileInfo(current).absolutePath();
    return QDir::toNativeSeparators(QFileDialog::getSaveFileName(nullptr, title, current.isEmpty() ? dir : current,
                                                                 QString(), nullptr,
                                                                 QFileDialog::DontConfirmOverwrite));
}

QString SettingsBackend::browseDirectory(const QString &title, const QString &current) const
{
    return QDir::toNativeSeparators(QFileDialog::getExistingDirectory(nullptr, title, current));
}

void SettingsBackend::openConfigFolder() const
{
    char *dir = config_GetUserDir(VLC_CONFIG_DIR);
    if (!dir)
        return;
    const QString path = qfu(dir);
    free(dir);
    QDir().mkpath(path);
    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

void SettingsBackend::resetAll()
{
    m_saveTimer.stop();
    config_ResetAll();
    config_SaveConfigFile(m_intf);
#ifdef _WIN32
    SPrefsPanel::setCurrentLanguage(QStringLiteral("auto"));
#endif
    if (m_intf->p_mi)
    {
        m_intf->p_mi->reloadPrefs();
        m_intf->p_mi->setAccentColor(QStringLiteral("default"));
    }
    bump(QString());
}

void SettingsBackend::resetHotkeys()
{
    size_t count = 0;
    module_t **list = module_list_get(&count);
    for (size_t i = 0; i < count; ++i)
    {
        unsigned confsize = 0;
        module_config_t *config = module_config_get(list[i], &confsize);
        for (unsigned j = 0; j < confsize; ++j)
        {
            const module_config_t &item = config[j];
            if (item.i_type != CONFIG_ITEM_KEY || !item.psz_name)
                continue;
            config_PutPsz(item.psz_name, item.orig.psz);
        }
        module_config_free(config);
    }
    module_list_free(list);
    bump(QString());
    scheduleSave();
}

void SettingsBackend::clearHistory()
{
    if (!m_intf->p_mi)
        return;
    MediaLib *ml = m_intf->p_mi->getMediaLibrary();
    if (!ml)
        return;
    ml->runOnMLThread(this, [](vlc_medialibrary_t *vlcMl) {
        vlc_ml_clear_history(vlcMl, VLC_ML_HISTORY_TYPE_GLOBAL);
    });
}

void SettingsBackend::openClassicPreferences() const
{
    DialogsProvider::getInstance()->classicPrefsDialog();
}

void SettingsBackend::openHotkeysEditor() const
{
    DialogsProvider::getInstance()->classicPrefsDialog(SPrefsHotkeys);
}

void SettingsBackend::openAddonsManager() const
{
    DialogsProvider::getInstance()->pluginDialog();
}

void SettingsBackend::save()
{
    m_saveTimer.stop();
    if (config_SaveConfigFile(m_intf) != 0)
        msg_Err(m_intf, "settings: cannot save the configuration file");
}

void SettingsBackend::bump(const QString &key)
{
    ++m_revision;
    emit revisionChanged();
    emit valueChanged(key);
}

void SettingsBackend::scheduleSave()
{
    m_saveTimer.start();
}
