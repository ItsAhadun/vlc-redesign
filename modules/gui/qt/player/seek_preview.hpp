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
#ifndef SEEK_PREVIEW_HPP
#define SEEK_PREVIEW_HPP

#include <QObject>
#include <QUrl>
#include <QHash>
#include <QTemporaryDir>

#include <memory>

Q_MOC_INCLUDE("player/player_controller.hpp")
Q_MOC_INCLUDE("maininterface/mainctx.hpp")

class PlayerController;
class MainCtx;
struct vlc_preparser_t;
struct vlc_preparser_req;
struct input_item_t;

/**
 * Seek-bar preview thumbnails ("thumbnail" component of the redesign).
 *
 * Generates still frames of the current media at a given position with the
 * core thumbnailer (vlc_preparser, VLC_PREPARSER_TYPE_THUMBNAIL_TO_FILES) and
 * exposes the last generated one as a local file URL. Positions are quantized
 * (`buckets`) and cached in a temporary directory, only one request runs at a
 * time and the most recent wish wins.
 */
class SeekPreview : public QObject
{
    Q_OBJECT

    Q_PROPERTY(PlayerController* player READ player WRITE setPlayer NOTIFY playerChanged FINAL)
    Q_PROPERTY(MainCtx* ctx MEMBER m_ctx NOTIFY ctxChanged FINAL)
    // requested width of the thumbnails in device pixels
    Q_PROPERTY(int thumbnailWidth MEMBER m_thumbnailWidth NOTIFY thumbnailWidthChanged FINAL)
    // url of the last available thumbnail (empty if none)
    Q_PROPERTY(QUrl source READ source NOTIFY sourceChanged FINAL)
    // position (0..1) the current source was taken at
    Q_PROPERTY(double sourcePosition READ sourcePosition NOTIFY sourceChanged FINAL)
    // false when the thumbnailer can not be used (no image encoder, ...)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged FINAL)

public:
    explicit SeekPreview(QObject* parent = nullptr);
    ~SeekPreview() override;

    PlayerController* player() const { return m_player; }
    void setPlayer(PlayerController* player);

    QUrl source() const { return m_source; }
    double sourcePosition() const { return m_sourcePosition; }
    bool available() const { return m_available; }

    // ask for a thumbnail near `position` (0..1)
    Q_INVOKABLE void request(double position);

signals:
    void playerChanged();
    void ctxChanged();
    void thumbnailWidthChanged();
    void sourceChanged();
    void availableChanged();

private:
    void reset();
    bool ensurePreparser();
    void submit(int bucket);
    void onThumbnailEnded(int bucket, bool success);
    void setSource(int bucket);

    static constexpr int BUCKETS = 200;

    PlayerController* m_player = nullptr;
    MainCtx* m_ctx = nullptr;
    int m_thumbnailWidth = 504;

    vlc_preparser_t* m_preparser = nullptr;
    vlc_preparser_req* m_req = nullptr;
    input_item_t* m_item = nullptr;

    std::unique_ptr<QTemporaryDir> m_dir;
    QString m_ext;
    int m_format = -1;
    QHash<int, QString> m_cache;

    int m_running = -1; // bucket being generated
    int m_wanted = -1;  // bucket to generate next
    int m_generation = 0; // bumped on media change, drops stale results

    QUrl m_source;
    double m_sourcePosition = 0.;
    bool m_available = true;
};

#endif // SEEK_PREVIEW_HPP
