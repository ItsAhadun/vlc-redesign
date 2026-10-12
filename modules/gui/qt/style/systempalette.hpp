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
#ifndef VLC_SYSTEMPALETTE_H
#define VLC_SYSTEMPALETTE_H

#include <QObject>
#include <QColor>
#include <QPalette>
#include <QQuickImageProvider>
#include <QQuickItem>
#include <QPointer>
#include <QtQml/QQmlParserStatus>

#include "qt.hpp"
#include "util/color_scheme_model.hpp"

#include "qtthemeprovider.hpp"

#include "colorcontext.hpp"

class SystemPalette;
class ColorProperty;
class ColorContextState;

Q_MOC_INCLUDE("maininterface/mainctx.hpp")

class CSDMetrics : public QObject {
    Q_OBJECT

    Q_PROPERTY(int interNavButtonSpacing MEMBER interNavButtonSpacing CONSTANT FINAL)

    Q_PROPERTY(int csdFrameMarginLeft MEMBER csdFrameMarginLeft CONSTANT FINAL)
    Q_PROPERTY(int csdFrameMarginRight MEMBER csdFrameMarginRight CONSTANT FINAL)
    Q_PROPERTY(int csdFrameMarginTop MEMBER csdFrameMarginTop CONSTANT FINAL)
    Q_PROPERTY(int csdFrameMarginBottom MEMBER csdFrameMarginBottom CONSTANT FINAL)

public:
    int interNavButtonSpacing = 0;

    int csdFrameMarginLeft = 0;
    int csdFrameMarginRight = 0;
    int csdFrameMarginTop = 0;
    int csdFrameMarginBottom = 0;
};

class ExternalPaletteImpl : public QObject
{
    Q_OBJECT
public:
    ExternalPaletteImpl(MainCtx* ctx, SystemPalette& palette, QObject* parent = nullptr);

    ~ExternalPaletteImpl();

    bool init();

    bool isThemeDark() const;

    QImage getCSDImage(vlc_qt_theme_csd_button_type type, vlc_qt_theme_csd_button_state state, bool maximized, bool active, int bannerHeight);
    CSDMetrics* getCSDMetrics() const;

    bool hasCSDImages() const;

    int update();
    void updateMetrics(vlc_qt_theme_image_type type);

signals:
    void paletteChanged();
    void CSDMetricsChanged();

public:
    SystemPalette& m_palette;
    MainCtx* m_ctx = nullptr;
    module_t* m_module = nullptr;
    vlc_qt_theme_provider_t* m_provider = nullptr;
    std::unique_ptr<CSDMetrics> m_csdMetrics;
};

#define COLOR_DEFINITION(name, value) \
    Q_PROPERTY(QColor name READ get_##name NOTIFY paletteChanged FINAL) \
public: \
    inline QColor get_## name() const { return name; } \
private: \
    QColor name {value}

/**
 * Raw design tokens of the redesign (design/SPEC.md section 1.1), they are
 * resolved for the current light/dark palette and accent color
 */
struct DesignTokens
{
    //foreground
    QColor fg1, fg2, fgA1, fgA2, fgA3, fgA4, fgB1;
    //backgrounds
    QColor bgA1, bgA2, bgA3, bgA4, bgA5, bgB1, bgB2;
    QColor bgA3Transparent, bgB1Transparent, bgB2Transparent;
    //dividers
    QColor dividerBright, dividerDim;
    //accent, derived from the selected accent color
    QColor accentMain, accentBright, accentDim, accentLogo;
    QColor bgAccentBright, bgAccentDark;
    QColor fgOnAccent;
    //misc
    QColor hoverOverlay;
    QColor volumeTrack, volumeGauge;
    QColor volumeGaugeLow, volumeGaugeMid, volumeGaugeHigh, volumeGaugePeak;
};

#define TOKEN_DEFINITION(name) \
    Q_PROPERTY(QColor name READ get_##name NOTIFY paletteChanged FINAL) \
public: \
    inline QColor get_## name() const { return m_tokens.name; } \
private:



class SystemPalette : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
public:
    Q_PROPERTY(MainCtx* ctx READ getCtx WRITE setCtx NOTIFY ctxChanged FINAL)
    Q_PROPERTY(ColorSchemeModel::ColorScheme  source READ source WRITE setSource NOTIFY sourceChanged FINAL)
    Q_PROPERTY(bool isDark MEMBER m_isDark NOTIFY paletteChanged FINAL)
    Q_PROPERTY(bool hasCSDImage READ hasCSDImage NOTIFY hasCSDImageChanged FINAL)
    Q_PROPERTY(CSDMetrics* csdMetrics READ getCSDMetrics NOTIFY CSDMetricsChanged FINAL)

    //standard color definitions used by light/dark themes
    COLOR_DEFINITION(orange500, "#FF8800");
    COLOR_DEFINITION(orange800, "#FF610A");

    COLOR_DEFINITION(orange400, "#f89a06"); //FIXME name have been chosen randomly by me
    COLOR_DEFINITION(orange200, "#e29a06"); //FIXME name have been chosen randomly by me

    COLOR_DEFINITION(darkGrey200, "#1E1E1E");
    COLOR_DEFINITION(darkGrey300, "#212121");
    COLOR_DEFINITION(darkGrey400, "#242424");
    COLOR_DEFINITION(darkGrey500, "#272727");
    COLOR_DEFINITION(darkGrey600, "#2A2A2A");
    COLOR_DEFINITION(darkGrey700, "#2D2D2D");
    COLOR_DEFINITION(darkGrey800, "#303030");

    COLOR_DEFINITION(lightGrey100, "#FAFAFA");
    COLOR_DEFINITION(lightGrey200, "#F6F6F6");
    COLOR_DEFINITION(lightGrey300, "#F2F2F2");
    COLOR_DEFINITION(lightGrey400, "#EDEDED");
    COLOR_DEFINITION(lightGrey500, "#E9E9E9");
    COLOR_DEFINITION(lightGrey600, "#E5E5E5");
    COLOR_DEFINITION(lightGrey700, "#E0E0E0");

    COLOR_DEFINITION(red500, "#FF0000");

    //design tokens, see DesignTokens
    TOKEN_DEFINITION(fg1)
    TOKEN_DEFINITION(fg2)
    TOKEN_DEFINITION(fgA1)
    TOKEN_DEFINITION(fgA2)
    TOKEN_DEFINITION(fgA3)
    TOKEN_DEFINITION(fgA4)
    TOKEN_DEFINITION(fgB1)

    TOKEN_DEFINITION(bgA1)
    TOKEN_DEFINITION(bgA2)
    TOKEN_DEFINITION(bgA3)
    TOKEN_DEFINITION(bgA4)
    TOKEN_DEFINITION(bgA5)
    TOKEN_DEFINITION(bgB1)
    TOKEN_DEFINITION(bgB2)
    TOKEN_DEFINITION(bgA3Transparent)
    TOKEN_DEFINITION(bgB1Transparent)
    TOKEN_DEFINITION(bgB2Transparent)

    TOKEN_DEFINITION(dividerBright)
    TOKEN_DEFINITION(dividerDim)

    TOKEN_DEFINITION(accentMain)
    TOKEN_DEFINITION(accentBright)
    TOKEN_DEFINITION(accentDim)
    TOKEN_DEFINITION(accentLogo)
    TOKEN_DEFINITION(bgAccentBright)
    TOKEN_DEFINITION(bgAccentDark)
    TOKEN_DEFINITION(fgOnAccent)

    TOKEN_DEFINITION(hoverOverlay)
    TOKEN_DEFINITION(volumeTrack)
    TOKEN_DEFINITION(volumeGauge)
    TOKEN_DEFINITION(volumeGaugeLow)
    TOKEN_DEFINITION(volumeGaugeMid)
    TOKEN_DEFINITION(volumeGaugeHigh)
    TOKEN_DEFINITION(volumeGaugePeak)

public:
    SystemPalette(QObject* parent = nullptr);

    ColorSchemeModel::ColorScheme source() const;
    QImage getCSDImage(vlc_qt_theme_csd_button_type type, vlc_qt_theme_csd_button_state state, bool maximized, bool active, int bannerHeight);
    CSDMetrics* getCSDMetrics() const;

    inline MainCtx* getCtx() const { return m_ctx; }
    bool hasCSDImage() const;

    void setColor(ColorContext::ColorSet colorSet,  ColorContext::ColorSection section,
                  ColorContext::ColorName name, ColorContext::ColorState state, QColor color);
    QColor getColor(ColorContext::ColorSet colorSet,  ColorContext::ColorSection section,
                    ColorContext::ColorName name, ColorContext::ColorState state) const;

    void classBegin() override { }
    void componentComplete() override;

public slots:
    void setSource(ColorSchemeModel::ColorScheme source);
    void setCtx(MainCtx* ctx);


signals:
    void sourceChanged();
    void paletteChanged();
    void hasCSDImageChanged();
    void ctxChanged();
    void CSDMetricsChanged();

private:
    void updatePalette();

    void makeLightPalette();
    void makeDarkPalette();
    void makeSystemPalette();

    void makeDesignTokens(bool dark);
    void makeTokenPalette();

private:
    MainCtx* m_ctx = nullptr;

    DesignTokens m_tokens;

    ColorSchemeModel::ColorScheme m_source = ColorSchemeModel::ColorScheme::Day;
    bool m_isDark = false;
    bool m_hasCSDImage = false;

    std::unique_ptr<ExternalPaletteImpl> m_palettePriv;

    QMap<quint64, QColor> m_colorMap;

};

#undef COLOR_PROPERTY
#undef COLOR_DEFINITION
#undef TOKEN_DEFINITION

#endif // VLC_SYSTEMPALETTE_H
