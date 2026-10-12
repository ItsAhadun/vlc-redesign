/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
#include "systempalette.hpp"
#include <QGuiApplication>
#include <QPalette>
#include <QSettings>
#include <QFile>
#include <algorithm>
#include <cmath>
#include <maininterface/mainctx.hpp>
#include <vlc_modules.h>
#include <vlc_picture.h>

namespace {

QColor setColorAlpha(const QColor& c1, float alpha)
{
    QColor c(c1);
    c.setAlphaF(alpha);
    return c;
}

//multiply each RGB channel by factor
QColor scaleColor(const QColor& c, float factor)
{
    return QColor::fromRgbF(
        std::min(1.f, c.redF() * factor),
        std::min(1.f, c.greenF() * factor),
        std::min(1.f, c.blueF() * factor),
        c.alphaF());
}

//linear interpolation from c1 (ratio = 0) to c2 (ratio = 1)
QColor mixColors(const QColor& c1, const QColor& c2, float ratio)
{
    return QColor::fromRgbF(
        c1.redF() + (c2.redF() - c1.redF()) * ratio,
        c1.greenF() + (c2.greenF() - c1.greenF()) * ratio,
        c1.blueF() + (c2.blueF() - c1.blueF()) * ratio,
        c1.alphaF() + (c2.alphaF() - c1.alphaF()) * ratio);
}

//"Accent/Bright" rule from the design: brighter and slightly less saturated
QColor brightenAccent(const QColor& c)
{
    float h, s, v;
    c.getHsvF(&h, &s, &v);
    return QColor::fromHsvF(h, s * 0.945f, std::min(1.f, v * 1.195f));
}

double relativeLuminance(const QColor& c)
{
    const auto channel = [](double v) {
        return (v <= 0.03928) ? v / 12.92 : std::pow((v + 0.055) / 1.055, 2.4);
    };
    return 0.2126 * channel(c.redF()) + 0.7152 * channel(c.greenF()) + 0.0722 * channel(c.blueF());
}

double contrastRatio(const QColor& c1, const QColor& c2)
{
    double l1 = relativeLuminance(c1);
    double l2 = relativeLuminance(c2);
    if (l1 < l2)
        std::swap(l1, l2);
    return (l1 + 0.05) / (l2 + 0.05);
}

#ifndef _WIN32
/**
 * function taken from QtBase gui/platform/unix/qgenericunixservices.cpp
 */
static inline QByteArray detectLinuxDesktopEnvironment()
{
    const QByteArray xdgCurrentDesktop = qgetenv("XDG_CURRENT_DESKTOP");
    if (!xdgCurrentDesktop.isEmpty())
        return xdgCurrentDesktop.toUpper(); // KDE, GNOME, UNITY, LXDE, MATE, XFCE...

    // Classic fallbacks
    if (!qEnvironmentVariableIsEmpty("KDE_FULL_SESSION"))
        return QByteArrayLiteral("KDE");
    if (!qEnvironmentVariableIsEmpty("GNOME_DESKTOP_SESSION_ID"))
        return QByteArrayLiteral("GNOME");

    // Fallback to checking $DESKTOP_SESSION (unreliable)
    QByteArray desktopSession = qgetenv("DESKTOP_SESSION");

    // This can be a path in /usr/share/xsessions
    int slash = desktopSession.lastIndexOf('/');
    if (slash != -1) {
        QSettings desktopFile(QFile::decodeName(desktopSession + ".desktop"), QSettings::IniFormat);
        desktopFile.beginGroup(QStringLiteral("Desktop Entry"));
        QByteArray desktopName = desktopFile.value(QStringLiteral("DesktopNames")).toByteArray();
        if (!desktopName.isEmpty())
            return desktopName;

        // try decoding just the basename
        desktopSession = desktopSession.mid(slash + 1);
    }

    if (desktopSession == "gnome")
        return QByteArrayLiteral("GNOME");
    else if (desktopSession == "xfce")
        return QByteArrayLiteral("XFCE");
    else if (desktopSession == "kde")
        return QByteArrayLiteral("KDE");

    return QByteArrayLiteral("UNKNOWN");
}

bool isGTKBasedEnvironment()
{
    QList<QByteArray> gtkBasedEnvironments{
        "GNOME",
        "X-CINNAMON",
        "UNITY",
        "MATE",
        "XFCE",
        "LXDE"
    };
    const QList<QByteArray> desktopNames = detectLinuxDesktopEnvironment().split(':');
    for (const QByteArray& desktopName: desktopNames)
    {
        if (gtkBasedEnvironments.contains(desktopName))
            return true;
    }
    return false;
}
#endif


static void PaletteChangedCallback(vlc_qt_theme_provider_t*, void* data)
{
    auto priv = static_cast<ExternalPaletteImpl*>(data);
    emit priv->paletteChanged();
}

static void MetricsChangedCallback(vlc_qt_theme_provider_t*, vlc_qt_theme_image_type type, void* data)
{
    auto priv = static_cast<ExternalPaletteImpl*>(data);
    assert(priv);
    priv->updateMetrics(type);
}


static void ReleaseVLCPictureCb(void* data)
{
    auto pic = static_cast<picture_t*>(data);
    if (pic)
        picture_Release(pic);
}


static void setColorRBGAInt(
    vlc_qt_theme_provider_t* obj,
    vlc_qt_theme_color_set set, vlc_qt_theme_color_section section,
    vlc_qt_theme_color_name name, vlc_qt_theme_color_state state,
    int r, int g, int b, int a)
{
    auto palette = static_cast<SystemPalette*>(obj->setColorData);
    QColor color(r,g,b,a);
    palette->setColor(
        static_cast<ColorContext::ColorSet>(set), static_cast<ColorContext::ColorSection>(section),
        static_cast<ColorContext::ColorName>(name), static_cast<ColorContext::ColorState>(state),
        color);
}

static void setColorRBGAFloat(
    vlc_qt_theme_provider_t* obj,
    vlc_qt_theme_color_set set, vlc_qt_theme_color_section section,
    vlc_qt_theme_color_name name, vlc_qt_theme_color_state state,
    double r, double g, double b, double a)
{
    auto palette = static_cast<SystemPalette*>(obj->setColorData);
    QColor color;
    color.setRgbF(r,g,b,a);
    palette->setColor(
        static_cast<ColorContext::ColorSet>(set), static_cast<ColorContext::ColorSection>(section),
        static_cast<ColorContext::ColorName>(name), static_cast<ColorContext::ColorState>(state),
        color);
}

}

//ExternalPaletteImpl

ExternalPaletteImpl::ExternalPaletteImpl(MainCtx* ctx, SystemPalette& palette, QObject* parent)
    : QObject(parent)
    , m_palette(palette)
    , m_ctx(ctx)
{
}

ExternalPaletteImpl::~ExternalPaletteImpl()
{
    if (m_provider)
    {
        if (m_provider->close)
            m_provider->close(m_provider);
        if (m_module)
            module_unneed(m_provider, m_module);
        vlc_object_delete(m_provider);
    }
}

bool ExternalPaletteImpl::init()
{
    QString preferedProvider;
#ifndef _WIN32
    if (isGTKBasedEnvironment())
        preferedProvider = "qt-themeprovider-gtk";
#endif

    m_provider = vlc_object_create<vlc_qt_theme_provider_t>(m_ctx->getIntf());
    if (!m_provider)
        return false;


    m_provider->paletteUpdated = PaletteChangedCallback;
    m_provider->paletteUpdatedData = this;

    m_provider->metricsUpdated = MetricsChangedCallback;
    m_provider->metricsUpdatedData = this;

    m_provider->setColorF = setColorRBGAFloat;
    m_provider->setColorInt = setColorRBGAInt;
    m_provider->setColorData = &m_palette;

    m_module = module_need(m_provider, "qt theme provider",
                           preferedProvider.isNull() ? nullptr : qtu(preferedProvider),
                           true);
    if (!m_module)
        return false;
    return true;
}

bool ExternalPaletteImpl::isThemeDark() const
{
    if (!m_provider->isThemeDark)
        return false;
    return m_provider->isThemeDark(m_provider);
}

bool ExternalPaletteImpl::hasCSDImages() const
{
    if (!m_provider->supportThemeImage)
        return false;
    return m_provider->supportThemeImage(m_provider, VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON);
}


QImage ExternalPaletteImpl::getCSDImage(vlc_qt_theme_csd_button_type type, vlc_qt_theme_csd_button_state state, bool maximized, bool active, int bannerHeight)
{
    if (!m_provider->getThemeImage)
        return {};
    vlc_qt_theme_image_setting imageSettings;
    imageSettings.windowScaleFactor = m_ctx->intfMainWindow()->devicePixelRatio();
    imageSettings.userScaleFacor = m_ctx->getIntfUserScaleFactor();
    imageSettings.u.csdButton.buttonType = type;
    imageSettings.u.csdButton.state = state;
    imageSettings.u.csdButton.maximized = maximized;
    imageSettings.u.csdButton.active = active;
    imageSettings.u.csdButton.bannerHeight = bannerHeight;
    picture_t* pic = m_provider->getThemeImage(m_provider, VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON, &imageSettings);
    if (!pic)
        return {};

    QImage::Format format = QImage::Format_Invalid;
    switch (pic->format.i_chroma)
    {
    case VLC_CODEC_ARGB:
        format = QImage::Format_ARGB32_Premultiplied;
        break;
    case VLC_CODEC_RGBA:
        format = QImage::Format_RGBA8888_Premultiplied;
        break;
    case VLC_CODEC_RGB24:
        format = QImage::Format_RGB888;
        break;
    default:
        msg_Err(m_ctx->getIntf(), "unexpected image format from theme provider");
        break;
    }

    return QImage(pic->p[0].p_pixels,
            pic->format.i_visible_width, pic->format.i_visible_height, pic->p[0].i_pitch,
            format,
            ReleaseVLCPictureCb, pic
            );
}

CSDMetrics* ExternalPaletteImpl::getCSDMetrics() const
{
    return m_csdMetrics.get();
}

int ExternalPaletteImpl::update()
{
    if (m_provider->updatePalette)
        return m_provider->updatePalette(m_provider);
    return VLC_EGENERIC;
}

void ExternalPaletteImpl::updateMetrics(vlc_qt_theme_image_type type)
{
    if (m_provider->getThemeMetrics)
    {
        if (type == VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON)
        {
            m_csdMetrics.reset();
            [&](){
                if (!m_provider->getThemeMetrics)
                    return;
                vlc_qt_theme_metrics metrics;
                memset(&metrics, 0, sizeof(metrics));
                bool ret = m_provider->getThemeMetrics(m_provider, VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON, &metrics);
                if (!ret)
                    return;
                m_csdMetrics = std::make_unique<CSDMetrics>();
                m_csdMetrics->interNavButtonSpacing = metrics.u.csd.interNavButtonSpacing;

                m_csdMetrics->csdFrameMarginLeft = metrics.u.csd.csdFrameMarginLeft;
                m_csdMetrics->csdFrameMarginRight = metrics.u.csd.csdFrameMarginRight;
                m_csdMetrics->csdFrameMarginTop = metrics.u.csd.csdFrameMarginTop;
                m_csdMetrics->csdFrameMarginBottom = metrics.u.csd.csdFrameMarginBottom;
            }();
            emit CSDMetricsChanged();
        }
    }
}

SystemPalette::SystemPalette(QObject* parent)
    : QObject(parent)
{

}

void SystemPalette::componentComplete()
{
    assert(m_ctx);
    updatePalette();
}

ColorSchemeModel::ColorScheme SystemPalette::source() const
{
    return m_source;
}

QImage SystemPalette::getCSDImage(vlc_qt_theme_csd_button_type type, vlc_qt_theme_csd_button_state state, bool maximized, bool active, int bannerHeight)
{
    if (!hasCSDImage())
        return QImage();
    assert(m_palettePriv);
    return m_palettePriv->getCSDImage(type, state, maximized, active, bannerHeight);

}

CSDMetrics* SystemPalette::getCSDMetrics() const
{
    if (!m_palettePriv)
        return nullptr;
    return m_palettePriv->getCSDMetrics();
}

bool SystemPalette::hasCSDImage() const
{
    if (!m_palettePriv)
        return false;
    return m_palettePriv->hasCSDImages();
}

void SystemPalette::setSource(ColorSchemeModel::ColorScheme source)
{
    if (m_source == source)
        return;
    m_source = source;

    updatePalette();
    emit sourceChanged();
}

void SystemPalette::setCtx(MainCtx* ctx)
{
    if (ctx == m_ctx)
        return;
    if (m_ctx)
        disconnect(m_ctx, &MainCtx::accentColorChanged, this, &SystemPalette::updatePalette);
    m_ctx = ctx;
    if (m_ctx)
        connect(m_ctx, &MainCtx::accentColorChanged, this, &SystemPalette::updatePalette);
    emit ctxChanged();
    updatePalette();
}

void SystemPalette::updatePalette()
{
    m_palettePriv.reset();
    switch(m_source)
    {
    case ColorSchemeModel::System:
        makeSystemPalette();
        break;
    case ColorSchemeModel::Day:
        makeLightPalette();
        break;
    case ColorSchemeModel::Night:
        makeDarkPalette();
        break;
    default:
        break;
    }

    if (m_palettePriv)
    {
        connect(
            m_palettePriv.get(), &ExternalPaletteImpl::paletteChanged,
            this, &SystemPalette::updatePalette);
        connect(
            m_palettePriv.get(), &ExternalPaletteImpl::CSDMetricsChanged,
            this, &SystemPalette::CSDMetricsChanged);
    }
    emit paletteChanged();

    bool hasCSDImage = m_palettePriv && m_palettePriv->hasCSDImages();
    if (m_hasCSDImage != hasCSDImage)
    {
        m_hasCSDImage = hasCSDImage;
        emit hasCSDImageChanged();
    }
}

static quint64 makeKey(ColorContext::ColorSet colorSet, ColorContext::ColorSection section,
                       ColorContext::ColorName name, ColorContext::ColorState state)
{
    static_assert(VQTC_STATE_COUNT < (1<<4), "");
    static_assert(VQTC_SECTION_COUNT < (1<<4), "");
    static_assert(VQTC_NAME_COUNT < (1<<8), "");
    static_assert(VQTC_SET_COUNT < (1<<16), "");
    return  (colorSet << 16)
        + (name << 8)
        + (section << 4)
        + state;
}

void SystemPalette::setColor(ColorContext::ColorSet colorSet,  ColorContext::ColorSection section,
                             ColorContext::ColorName name, ColorContext::ColorState state, QColor color)
{

    quint64 key = makeKey(colorSet, section, name, state);
    m_colorMap[key] = color;
}


QColor SystemPalette::getColor(ColorContext::ColorSet colorSet, ColorContext::ColorSection section,
                               ColorContext::ColorName name, ColorContext::ColorState state) const
{
    typedef ColorContext C;

    quint64 key = makeKey(colorSet, section, name, state);
    auto it = m_colorMap.find(key);
    if (it != m_colorMap.cend())
        return *it;
    //we don't have the role explicitly set, fallback to the normal state
    key = makeKey(colorSet, section, name, C::Normal);
    it = m_colorMap.find(key);
    if (it != m_colorMap.cend())
        return *it;
    //we don't have the role explicitly set, fallback to the colorSet View
    //TODO do we want finer hierarchy?
    if (colorSet != C::View)
    {
        return getColor(C::View, section, name, state);
    }
    else
    {
        //nothing matches, that's probably an issue, return an ugly color
        return Qt::magenta;
    }
}


void SystemPalette::makeDesignTokens(bool dark)
{
    DesignTokens& T = m_tokens;

    //values from design/SPEC.md section 1.1
    if (dark)
    {
        T.fg1  = QColor("#eaeaea");
        T.fg2  = QColor("#c6c6c6");
        T.fgA1 = QColor("#969696");
        T.fgA2 = QColor("#8f8f8f");
        T.fgA3 = QColor("#6b6b6b");
        T.fgA4 = QColor("#404040");
        T.fgB1 = QColor("#161616");

        T.bgA1 = QColor("#222222");
        T.bgA2 = QColor("#1f1f1f");
        T.bgA3 = QColor("#1b1b1b");
        T.bgA4 = QColor("#191919");
        T.bgA5 = QColor("#151515");
        T.bgB1 = QColor("#0e0e0e");
        T.bgB2 = QColor("#090909");
        T.bgA3Transparent = setColorAlpha(T.bgA4, 0.95); // #191919/0.95 in the design
        T.bgB1Transparent = setColorAlpha(T.bgB1, 0.95);
        T.bgB2Transparent = setColorAlpha(Qt::black, 0.80);

        T.dividerBright = QColor("#373737");
        T.dividerDim    = QColor("#222222");

        T.hoverOverlay = setColorAlpha(Qt::white, 0.06);
        T.volumeTrack  = QColor("#262626");
    }
    else
    {
        T.fg1  = QColor("#eaeaea");
        T.fg2  = QColor("#c6c6c6");
        T.fgA1 = QColor("#3c3c3c");
        T.fgA2 = QColor("#2e2e2e");
        T.fgA3 = QColor("#6b6b6b");
        T.fgA4 = QColor("#3b3b3b");
        T.fgB1 = QColor("#161616");

        T.bgA1 = QColor("#ededed");
        T.bgA2 = QColor("#dddddd");
        T.bgA3 = QColor("#d5d5d5");
        T.bgA4 = QColor("#b3b3b3");
        T.bgA5 = QColor("#888888");
        T.bgB1 = QColor("#e7e7e7");
        T.bgB2 = QColor("#dedede");
        T.bgA3Transparent = setColorAlpha(T.bgA3, 0.75);
        T.bgB1Transparent = setColorAlpha(T.bgB1, 0.80);
        T.bgB2Transparent = setColorAlpha(Qt::black, 0.80); //not defined in the light set

        T.dividerBright = QColor("#9b9b9b");
        T.dividerDim    = QColor("#acacac");

        T.hoverOverlay = setColorAlpha(Qt::black, 0.06);
        T.volumeTrack  = QColor("#c6c6c6");
    }

    //accent tints, derived from the selected accent (design/SPEC.md section 1.3)
    const QColor accent = m_ctx ? m_ctx->accentColor() : QColor("#d37918");
    if (dark)
    {
        T.accentMain     = accent;
        T.accentDim      = scaleColor(accent, 0.81);
        T.accentLogo     = accent;
        T.bgAccentBright = scaleColor(accent, 0.26);
        T.bgAccentDark   = mixColors(QColor("#111111"), accent, 0.048);
    }
    else
    {
        //light variant is about the accent with V * 1.10 (orange #d37918 -> #e8851a)
        T.accentMain     = scaleColor(accent, 1.10);
        T.accentDim      = scaleColor(T.accentMain, 0.65);
        T.accentLogo     = scaleColor(T.accentMain, 0.84);
        T.bgAccentBright = mixColors(QColor("#cfcfcf"), T.accentMain, 0.30);
        T.bgAccentDark   = mixColors(QColor("#bdbdbd"), T.accentMain, 0.30);
    }
    T.accentBright = brightenAccent(T.accentMain);

    //glyphs on the accent (play button): dark glyph unless the accent is too dark for it
    T.fgOnAccent = (contrastRatio(T.accentMain, T.fgB1) >= contrastRatio(T.accentMain, T.fg1))
            ? T.fgB1 : T.fg1;

    //volume gauge, fixed colors (not accent derived)
    T.volumeGauge     = QColor("#9bb019");
    T.volumeGaugeLow  = QColor("#95d318");
    T.volumeGaugeMid  = QColor("#b2a918");
    T.volumeGaugeHigh = QColor("#d37918");
    T.volumeGaugePeak = QColor("#ff3737");
}

void SystemPalette::makeLightPalette()
{
    m_isDark = false;
    m_colorMap.clear();
    makeDesignTokens(false);
    makeTokenPalette();
}

void SystemPalette::makeDarkPalette()
{
    m_isDark = true;
    m_colorMap.clear();
    makeDesignTokens(true);
    makeTokenPalette();
}

void SystemPalette::makeTokenPalette()
{
    typedef ColorContext C;
    const DesignTokens& T = m_tokens;
    const bool dark = m_isDark;

    //semantic roles shared by the color sets below
    const QColor textPrimary   = dark ? T.fg2  : T.fgA2;
    const QColor textSecondary = dark ? T.fgA2 : T.fgA3;
    const QColor textStrong    = dark ? T.fg1  : T.fgA2;
    const QColor textDisabled  = dark ? T.fgA4 : setColorAlpha(T.fgA2, 0.35);
    const QColor surfaceHover    = dark ? T.bgA1 : T.bgA2;
    const QColor surfaceSelected = dark ? T.bgA1 : T.bgA3;

    //base set
    {
        C::ColorSet CS = C::View;
        setColor(CS, C::Bg, C::Primary, C::Normal, T.bgB1);
        setColor(CS, C::Bg, C::Secondary, C::Normal, T.bgB2);

        setColor(CS, C::Fg, C::Primary, C::Normal, textPrimary);
        setColor(CS, C::Fg, C::Primary, C::Disabled, textDisabled);

        setColor(CS, C::Fg, C::Secondary, C::Normal, textSecondary);
        setColor(CS, C::Fg, C::Secondary, C::Disabled, textDisabled);

        setColor(CS, C::Bg, C::Highlight, C::Normal, surfaceSelected);
        setColor(CS, C::Fg, C::Highlight, C::Normal, textStrong);

        if (dark)
        {
            setColor(CS, C::Bg, C::Negative, C::Normal, QColor(Qt::darkRed));
            setColor(CS, C::Bg, C::Neutral, C::Normal, QColor(Qt::darkYellow));
            setColor(CS, C::Bg, C::Positive, C::Normal, QColor(Qt::darkGreen));
        }
        else
        {
            setColor(CS, C::Bg, C::Negative, C::Normal, QColor("#fde7e9")); //FIXME
            setColor(CS, C::Bg, C::Neutral, C::Normal, QColor("#e4dab8")); //FIXME
            setColor(CS, C::Bg, C::Positive, C::Normal, QColor("#dff6dd")); //FIXME
        }
        setColor(CS, C::Fg, C::Negative, C::Normal, Qt::red);
        setColor(CS, C::Fg, C::Neutral, C::Normal, T.accentMain);
        setColor(CS, C::Fg, C::Positive, C::Normal, Qt::green);

        setColor(CS, C::Decoration, C::VisualFocus, C::Normal, setColorAlpha(textStrong, 0.0));
        setColor(CS, C::Decoration, C::VisualFocus, C::Focused, textStrong);

        setColor(CS, C::Decoration, C::Border, C::Normal, T.dividerBright);
        setColor(CS, C::Decoration, C::Border, C::Focused, T.fgA3);
        setColor(CS, C::Decoration, C::Border, C::Hovered, T.fgA3);
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(T.dividerBright, 0.0));

        setColor(CS, C::Decoration, C::Separator, C::Normal, T.dividerDim);

        setColor(CS, C::Decoration, C::Shadow, C::Normal, setColorAlpha(Qt::black, 0.22));

        setColor(CS, C::Decoration, C::Accent, C::Normal, T.accentMain);
        setColor(CS, C::Fg, C::Link, C::Normal, T.accentMain);

        setColor(CS, C::Decoration, C::Indicator, C::Normal, T.fgA3);
    }

    //window chrome: title bar, control bar, nav pane, miniplayer, dialogs
    {
        C::ColorSet CS = C::Window;
        //light chrome uses BG/A4 (see design/SPEC.md light theme caveats)
        setColor(CS, C::Bg, C::Primary, C::Normal, dark ? T.bgA3 : T.bgA4);
        setColor(CS, C::Bg, C::Secondary, C::Normal, dark ? T.bgA4 : T.bgA3);
        setColor(CS, C::Decoration, C::Border, C::Normal, T.dividerDim);
        setColor(CS, C::Decoration, C::Separator, C::Normal, T.dividerDim);
    }

    //badges
    {
        C::ColorSet CS = C::Badge;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(Qt::black, 0.6));
        setColor(CS, C::Fg, C::Primary, C::Normal, T.fg1);
    }

    //tab button
    {
        C::ColorSet CS = C::TabButton;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(surfaceHover, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, surfaceHover);
        setColor(CS, C::Bg, C::Primary, C::Hovered, surfaceHover);

        setColor(CS, C::Fg, C::Primary, C::Normal, textSecondary);
        setColor(CS, C::Fg, C::Primary, C::Focused, textStrong);
        setColor(CS, C::Fg, C::Primary, C::Hovered, textStrong);
        setColor(CS, C::Fg, C::Primary, C::Disabled, textDisabled);
        setColor(CS, C::Fg, C::Secondary, C::Normal, textStrong);
    }

    //tool button
    {
        C::ColorSet CS = C::ToolButton;
        setColor(CS, C::Bg, C::Primary, C::Normal, Qt::transparent);
        setColor(CS, C::Bg, C::Primary, C::Hovered, T.hoverOverlay);
        setColor(CS, C::Bg, C::Secondary, C::Normal, T.bgB2);

        setColor(CS, C::Fg, C::Primary, C::Normal, textSecondary);
        setColor(CS, C::Fg, C::Primary, C::Focused, textStrong);
        setColor(CS, C::Fg, C::Primary, C::Hovered, textStrong);
        setColor(CS, C::Fg, C::Primary, C::Disabled, textDisabled);
        setColor(CS, C::Fg, C::Secondary, C::Normal, textStrong);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //menubar
    {
        C::ColorSet CS = C::MenuBar;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(surfaceHover, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, surfaceHover);
        setColor(CS, C::Bg, C::Primary, C::Hovered, surfaceHover);
        setColor(CS, C::Fg, C::Primary, C::Normal, textPrimary);
        setColor(CS, C::Fg, C::Primary, C::Disabled, textDisabled);
    }

    //Item
    {
        C::ColorSet CS = C::Item;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(surfaceHover, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, surfaceHover);
        setColor(CS, C::Bg, C::Primary, C::Hovered, surfaceHover);

        setColor(CS, C::Bg, C::Highlight, C::Normal, surfaceSelected);
        setColor(CS, C::Bg, C::Highlight, C::Focused, surfaceSelected);
        setColor(CS, C::Bg, C::Highlight, C::Hovered, surfaceSelected);
        setColor(CS, C::Fg, C::Highlight, C::Normal, textStrong);

        setColor(CS, C::Fg, C::Primary, C::Normal, textPrimary);
        setColor(CS, C::Fg, C::Secondary, C::Normal, textSecondary);

        setColor(CS, C::Decoration, C::Indicator, C::Normal, T.fgA3);
    }

    //Accent Buttons
    {
        C::ColorSet CS = C::ButtonAccent;
        setColor(CS, C::Bg, C::Primary, C::Normal, T.accentMain);
        setColor(CS, C::Bg, C::Primary, C::Hovered, T.accentBright);
        setColor(CS, C::Bg, C::Primary, C::Focused, T.accentBright);
        setColor(CS, C::Bg, C::Primary, C::Pressed, T.accentDim);
        setColor(CS, C::Bg, C::Primary, C::Disabled, setColorAlpha(textSecondary, 0.2));

        setColor(CS, C::Fg, C::Primary, C::Normal, T.fgOnAccent);
        setColor(CS, C::Fg, C::Primary, C::Disabled, textDisabled);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //Standard Buttons
    {
        C::ColorSet CS = C::ButtonStandard;
        setColor(CS, C::Bg, C::Primary, C::Normal, Qt::transparent);

        setColor(CS, C::Fg, C::Primary, C::Normal, textSecondary);
        setColor(CS, C::Fg, C::Primary, C::Focused, textStrong);
        setColor(CS, C::Fg, C::Primary, C::Hovered, textStrong);
        setColor(CS, C::Fg, C::Primary, C::Disabled, textDisabled);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //tooltip
    {
        C::ColorSet CS = C::Tooltip;
        setColor(CS, C::Bg, C::Primary, C::Normal, dark ? T.bgA2 : T.bgA1);
        setColor(CS, C::Fg, C::Primary, C::Normal, textPrimary);
    }

    //slider
    {
        C::ColorSet CS = C::Slider;
        setColor(CS, C::Bg, C::Primary, C::Normal, T.bgB2);
        setColor(CS, C::Bg, C::Secondary, C::Normal, setColorAlpha(T.fgA3, 0.3));

        setColor(CS, C::Fg, C::Primary, C::Normal, T.accentMain);
        setColor(CS, C::Fg, C::Positive, C::Normal, "#0F7B0F");  //FIXME
        setColor(CS, C::Fg, C::Neutral, C::Normal, "#9D5D00");  //FIXME
        setColor(CS, C::Fg, C::Negative, C::Normal, "#C42B1C");  //FIXME
    }

    //Combo box
    {
        C::ColorSet CS = C::ComboBox;
        setColor(CS, C::Fg, C::Primary, C::Normal, textPrimary);
        setColor(CS, C::Bg, C::Primary, C::Normal, T.bgA4);
        setColor(CS, C::Bg, C::Secondary, C::Normal, T.bgB2);
    }

    //TextField
    {
        C::ColorSet CS = C::TextField;
        setColor(CS, C::Decoration, C::Border, C::Normal, T.dividerBright);
        setColor(CS, C::Decoration, C::Border, C::Focused, T.accentMain);
        setColor(CS, C::Decoration, C::Border, C::Hovered, T.fgA3);
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(T.dividerBright, 0.0));

        setColor(CS, C::Bg, C::Highlight, C::Normal, T.accentDim);
        setColor(CS, C::Fg, C::Highlight, C::Normal, T.fg1);
    }

    //Switch
    {
        C::ColorSet CS = C::Switch;
        setColor(CS, C::Bg, C::Primary, C::Normal, T.bgB2);
        setColor(CS, C::Fg, C::Primary, C::Normal, T.fgA4);
        setColor(CS, C::Decoration, C::Border, C::Normal, T.dividerBright);

        setColor(CS, C::Bg, C::Secondary, C::Normal, T.bgAccentBright);
        setColor(CS, C::Fg, C::Secondary, C::Normal, T.accentDim);
    }

    //SpinBox
    {
        C::ColorSet CS = C::SpinBox;
        setColor(CS, C::Decoration, C::Border, C::Normal, T.dividerBright);
        setColor(CS, C::Decoration, C::Border, C::Focused, T.accentMain);
        setColor(CS, C::Decoration, C::Border, C::Hovered, T.fgA3);
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(T.dividerBright, 0.0));

        setColor(CS, C::Bg, C::Highlight, C::Normal, T.accentDim);
        setColor(CS, C::Fg, C::Highlight, C::Normal, T.fg1);
    }
}

void SystemPalette::makeSystemPalette()
{
    if (!m_ctx)
    {
        //can't initialise system palette, fallback to default
        makeLightPalette();
        return;
    }

    auto palette = std::make_unique<ExternalPaletteImpl>(m_ctx, *this);
    if (!palette->init())
    {
        //can't initialise system palette, fallback to default
        makeLightPalette();
        return;
    }

    m_colorMap.clear();
    int ret = palette->update();
#ifndef _WIN32
    // The system theme follows the dark/light preference of the desktop but
    // keeps the VLC palette. On Windows the provider only overrides the
    // palette in high contrast mode, which we must honor.
    ret = VLC_EGENERIC;
#endif
    if (ret != VLC_SUCCESS)
    {
        if (palette->isThemeDark())
            makeDarkPalette();
        else
            makeLightPalette();
    }
    else
    {
        m_isDark = palette->isThemeDark();
        makeDesignTokens(m_isDark);
    }

    m_palettePriv = std::move(palette);
}
