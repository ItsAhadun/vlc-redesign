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
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "seek_preview.hpp"

#include "qt.hpp"
#include "player/player_controller.hpp"
#include "maininterface/mainctx.hpp"

#include <vlc_common.h>
#include <vlc_player.h>
#include <vlc_preparser.h>
#include <vlc_input_item.h>
#include <vlc_configuration.h>

#include <QPointer>
#include <QMetaObject>

#include <algorithm>
#include <cmath>

namespace {

struct RequestContext
{
    QPointer<SeekPreview> preview;
    int bucket;
    int generation;
};

} // namespace

SeekPreview::SeekPreview(QObject* parent)
    : QObject(parent)
{
}

SeekPreview::~SeekPreview()
{
    if (m_preparser)
    {
        if (m_req)
        {
            vlc_preparser_Cancel(m_preparser, m_req);
            vlc_preparser_req_Release(m_req);
            m_req = nullptr;
        }
        // waits for the pending callbacks
        vlc_preparser_Delete(m_preparser);
    }
    if (m_item)
        input_item_Release(m_item);
}

void SeekPreview::setPlayer(PlayerController* player)
{
    if (m_player == player)
        return;

    if (m_player)
        disconnect(m_player, nullptr, this, nullptr);

    m_player = player;

    if (m_player)
        connect(m_player, &PlayerController::inputChanged, this, &SeekPreview::reset);

    reset();
    emit playerChanged();
}

void SeekPreview::reset()
{
    ++m_generation;

    if (m_req)
    {
        vlc_preparser_Cancel(m_preparser, m_req);
        vlc_preparser_req_Release(m_req);
        m_req = nullptr;
    }
    m_running = -1;
    m_wanted = -1;

    if (m_item)
    {
        input_item_Release(m_item);
        m_item = nullptr;
    }

    m_cache.clear();
    m_dir.reset();

    if (!m_source.isEmpty())
    {
        m_source.clear();
        m_sourcePosition = 0.;
        emit sourceChanged();
    }
}

bool SeekPreview::ensurePreparser()
{
    if (m_preparser)
        return true;
    if (!m_available || !m_ctx || !m_ctx->getIntf())
        return false;

    // honor the redesign option if the settings window added it
    // ("Show thumbnail while scrubbing", design/SPEC.md Playback settings)
    qt_intf_t* intf = m_ctx->getIntf();
    if (config_FindConfig("qt-seek-thumbnail") && !var_InheritBool(intf, "qt-seek-thumbnail"))
        return false;

    enum vlc_thumbnailer_format format;
    const char* ext = nullptr;
    if (vlc_preparser_GetBestThumbnailerFormat(&format, &ext) != VLC_SUCCESS)
    {
        m_available = false;
        emit availableChanged();
        return false;
    }
    m_format = format;
    m_ext = QString::fromLatin1(ext);

    struct vlc_preparser_cfg cfg{};
    cfg.types = VLC_PREPARSER_TYPE_THUMBNAIL_TO_FILES;
    cfg.max_thumbnailer_threads = 1;
    cfg.timeout = VLC_TICK_FROM_SEC(5);
    cfg.external_process = false;

    m_preparser = vlc_preparser_New(VLC_OBJECT(intf), &cfg);
    if (!m_preparser)
    {
        m_available = false;
        emit availableChanged();
        return false;
    }
    return true;
}

void SeekPreview::request(double position)
{
    if (!m_player || !std::isfinite(position))
        return;

    const int bucket = std::clamp(static_cast<int>(std::lround(position * BUCKETS)), 0, BUCKETS);

    if (m_cache.contains(bucket))
    {
        m_wanted = -1;
        setSource(bucket);
        return;
    }

    if (m_running >= 0)
    {
        // a request is already running, remember the latest wish only
        m_wanted = bucket;
        return;
    }

    submit(bucket);
}

void SeekPreview::submit(int bucket)
{
    if (!ensurePreparser())
        return;

    if (!m_item)
    {
        vlc_player_t* player = m_player->getPlayer();
        vlc_player_Lock(player);
        input_item_t* item = vlc_player_GetCurrentMedia(player);
        if (item)
            m_item = input_item_Hold(item);
        vlc_player_Unlock(player);
        if (!m_item)
            return;
    }

    if (!m_dir)
    {
        m_dir = std::make_unique<QTemporaryDir>();
        if (!m_dir->isValid())
        {
            m_dir.reset();
            return;
        }
    }

    const QString path = m_dir->filePath(QStringLiteral("seek-%1-%2.%3")
                                             .arg(m_generation).arg(bucket).arg(m_ext));
    const QByteArray pathUtf8 = path.toUtf8();

    struct vlc_thumbnailer_arg arg{};
    arg.seek.type = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_POS;
    arg.seek.pos = static_cast<double>(bucket) / BUCKETS;
    arg.seek.speed = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_FAST;
    arg.hw_dec = false;

    struct vlc_thumbnailer_output output{};
    output.format = static_cast<enum vlc_thumbnailer_format>(m_format);
    output.width = m_thumbnailWidth;
    output.height = 0; // keep the aspect ratio
    output.crop = false;
    output.file_path = pathUtf8.constData();
    output.creat_mode = 0600;

    static const struct vlc_thumbnailer_to_files_cbs cbs = [] {
        struct vlc_thumbnailer_to_files_cbs c{};
        c.on_ended = [](vlc_preparser_req*, int status, const bool* results,
                        size_t count, void* data) {
            auto* ctx = static_cast<RequestContext*>(data);
            const bool success = (status == VLC_SUCCESS) && results && count > 0 && results[0];
            QPointer<SeekPreview> preview = ctx->preview;
            const int bucket = ctx->bucket;
            const int generation = ctx->generation;
            delete ctx;
            if (!preview)
                return;
            QMetaObject::invokeMethod(preview.data(), [preview, bucket, generation, success]() {
                if (preview && preview->m_generation == generation)
                    preview->onThumbnailEnded(bucket, success);
            }, Qt::QueuedConnection);
        };
        return c;
    }();

    auto* ctx = new RequestContext{ QPointer<SeekPreview>(this), bucket, m_generation };
    vlc_preparser_req* req = vlc_preparser_req_NewThumbnailToFiles(m_preparser, m_item, &arg,
                                                                   &output, 1, &cbs, ctx);
    if (!req)
    {
        delete ctx;
        return;
    }

    if (vlc_preparser_Submit(m_preparser, req) != VLC_SUCCESS)
    {
        // the callback is not called if the submission failed
        delete ctx;
        vlc_preparser_req_Release(req);
        return;
    }

    m_req = req;
    m_running = bucket;
}

void SeekPreview::onThumbnailEnded(int bucket, bool success)
{
    if (m_req)
    {
        vlc_preparser_req_Release(m_req);
        m_req = nullptr;
    }
    m_running = -1;

    if (success && m_dir)
    {
        m_cache.insert(bucket, m_dir->filePath(QStringLiteral("seek-%1-%2.%3")
                                                   .arg(m_generation).arg(bucket).arg(m_ext)));
        setSource(bucket);
    }

    if (m_wanted >= 0 && m_wanted != bucket)
    {
        const int next = m_wanted;
        m_wanted = -1;
        if (m_cache.contains(next))
            setSource(next);
        else
            submit(next);
    }
    else
    {
        m_wanted = -1;
    }
}

void SeekPreview::setSource(int bucket)
{
    const QUrl url = QUrl::fromLocalFile(m_cache.value(bucket));
    if (url == m_source)
        return;
    m_source = url;
    m_sourcePosition = static_cast<double>(bucket) / BUCKETS;
    emit sourceChanged();
}
