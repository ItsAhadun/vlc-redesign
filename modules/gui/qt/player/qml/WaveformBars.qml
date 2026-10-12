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
import QtQuick

import VLC.Style

// Decorative waveform: vertical bars with deterministic pseudo-random heights.
//
// This is NOT an audio analysis (design decision): the shape is generated from
// `seed` (e.g. the media URI), so the same track always shows the same shape.
// The shape is defined by `sampleCount` samples and resampled to the number of
// bars that fit the width, so it keeps its look when the item is resized.
// Painted once in a Canvas, cheap to keep at any width.
Canvas {
    id: root

    property string seed: ""
    property color color: "grey"

    property real barWidth: VLCStyle.dp(2, VLCStyle.scale)
    property real barSpacing: VLCStyle.dp(3, VLCStyle.scale)
    // smallest bar, drawn as a dot
    property real minimumBarHeight: VLCStyle.dp(2, VLCStyle.scale)

    property int sampleCount: 256

    readonly property var samples: _generate(seed, sampleCount)

    renderTarget: Canvas.Image
    renderStrategy: Canvas.Immediate

    onSamplesChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onBarWidthChanged: requestPaint()
    onBarSpacingChanged: requestPaint()

    // 32 bit FNV-1a hash of a string
    function _hash(str) {
        let h = 0x811c9dc5
        for (let i = 0; i < str.length; ++i) {
            h ^= str.charCodeAt(i)
            h = Math.imul(h, 0x01000193)
        }
        return h >>> 0
    }

    // mulberry32 PRNG, returns a function giving floats in [0, 1)
    function _prng(a) {
        return function() {
            a |= 0
            a = (a + 0x6D2B79F5) | 0
            let t = Math.imul(a ^ (a >>> 15), 1 | a)
            t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296
        }
    }

    function _generate(seed, count) {
        const rand = _prng(_hash(seed || "vlc"))

        // slow "loudness" envelope: a few sines with random phases
        const waves = []
        for (let k = 0; k < 4; ++k)
            waves.push({ f: 1 + rand() * 6 * (k + 1), p: rand() * Math.PI * 2, a: 0.5 / (k + 1) })

        // discrete levels, like the design (dots, short, medium, tall bars)
        const levels = [0.0, 0.3, 0.5, 0.72, 0.9]

        const out = new Array(count)
        for (let i = 0; i < count; ++i) {
            const t = i / count
            let env = 0
            for (const w of waves)
                env += w.a * Math.sin(w.f * t * Math.PI * 2 + w.p)
            // normalize roughly to 0..1 and add per-bar jitter
            const v = Math.max(0, Math.min(1, 0.45 + env * 0.45 + (rand() - 0.5) * 0.55))
            out[i] = levels[Math.min(levels.length - 1, Math.floor(v * levels.length))]
        }
        return out
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()

        const n = samples.length
        if (n === 0 || width <= 0 || height <= 0)
            return

        const pitch = barWidth + barSpacing
        const bars = Math.max(1, Math.floor((width + barSpacing) / pitch))
        // center the bars horizontally
        const x0 = (width - (bars * pitch - barSpacing)) / 2

        ctx.fillStyle = color
        for (let i = 0; i < bars; ++i) {
            const s = samples[Math.min(n - 1, Math.floor(i * n / bars))]
            const h = Math.max(minimumBarHeight, Math.round(s * height))
            const x = Math.round(x0 + i * pitch)
            const y = Math.round((height - h) / 2)
            ctx.fillRect(x, y, barWidth, h)
        }
    }
}
