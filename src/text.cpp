//! Native Graphite text for Canvas 2D (system FontMgr).

#include "canvas_runtime.h"

#include "include/core/SkCanvas.h"
#include "include/core/SkFont.h"
#include "include/core/SkFontMetrics.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkFontStyle.h"
#include "include/core/SkPaint.h"
#include "include/core/SkString.h"
#include "include/core/SkTypeface.h"

#if defined(SK_BUILD_FOR_MAC) || defined(__APPLE__)
#include "include/ports/SkFontMgr_mac_ct.h"
#endif

namespace {

sk_sp<SkFontMgr> makeFontMgr() {
#if defined(SK_BUILD_FOR_MAC) || defined(__APPLE__)
    if (auto mgr = SkFontMgr_New_CoreText(nullptr)) return mgr;
#endif
    return nullptr;
}

void ensureFont(CanvasExtra& extra) {
    if (extra.font_mgr) return;
    extra.font_mgr = makeFontMgr();
    if (extra.font_mgr) {
        sk_sp<SkTypeface> face = extra.font_mgr->legacyMakeTypeface(nullptr, SkFontStyle());
        extra.font = SkFont(face, 16.f);
    }
}

float alignOffset(const CanvasExtra& extra, float width) {
    if (extra.text_align == 1) return width * 0.5f;
    if (extra.text_align == 2) return width;
    return 0.f;
}

float baselineOffset(const CanvasExtra& extra) {
    SkFontMetrics metrics;
    extra.font.getMetrics(&metrics);
    switch (extra.text_baseline) {
        case 1:
            return -metrics.fAscent;
        case 2:
            return -(metrics.fAscent + metrics.fDescent) * 0.5f;
        case 3:
            return -metrics.fDescent;
        default:
            return 0.f;
    }
}

} // namespace

extern "C" void fg_canvas_set_font(
    FGCanvas* canvas,
    float size_px,
    uint32_t weight,
    uint32_t italic,
    const char* family,
    uint32_t family_len
) {
    if (canvas == nullptr) return;
    CanvasExtra& extra = fgExtra(canvas);
    ensureFont(extra);
    if (!extra.font_mgr) return;

    SkFontStyle::Weight sk_weight = SkFontStyle::kNormal_Weight;
    if (weight >= 700) sk_weight = SkFontStyle::kBold_Weight;
    else if (weight <= 300) sk_weight = SkFontStyle::kLight_Weight;
    const SkFontStyle style(
        sk_weight,
        SkFontStyle::kNormal_Width,
        italic ? SkFontStyle::kItalic_Slant : SkFontStyle::kUpright_Slant);

    SkString name;
    if (family != nullptr && family_len > 0) {
        name.set(family, family_len);
    }
    sk_sp<SkTypeface> face = extra.font_mgr->legacyMakeTypeface(
        name.isEmpty() ? nullptr : name.c_str(),
        style);
    if (!face) {
        face = extra.font_mgr->legacyMakeTypeface(nullptr, style);
    }
    extra.font = SkFont(face, size_px > 0.f ? size_px : 16.f);
}

extern "C" void fg_canvas_set_text_align(FGCanvas* canvas, uint32_t align) {
    if (canvas == nullptr) return;
    fgExtra(canvas).text_align = align;
}

extern "C" void fg_canvas_set_text_baseline(FGCanvas* canvas, uint32_t baseline) {
    if (canvas == nullptr) return;
    fgExtra(canvas).text_baseline = baseline;
}

extern "C" FGStatus fg_canvas_fill_text(
    FGCanvas* canvas,
    const char* utf8,
    uint32_t utf8_len,
    float x,
    float y,
    float max_width,
    FGError* out_error
) {
    if (canvas == nullptr || canvas->sk == nullptr || utf8 == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "FGCanvas/text is null");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    CanvasExtra& extra = fgExtra(canvas);
    ensureFont(extra);
    const float width = extra.font.measureText(utf8, utf8_len, SkTextEncoding::kUTF8);
    float draw_x = x - alignOffset(extra, width);
    float draw_y = y + baselineOffset(extra);
    SkPaint paint = fgFillPaint(canvas);
    if (max_width > 0.f && width > max_width && width > 0.f) {
        canvas->sk->save();
        canvas->sk->translate(draw_x, draw_y);
        canvas->sk->scale(max_width / width, 1.f);
        canvas->sk->drawSimpleText(utf8, utf8_len, SkTextEncoding::kUTF8, 0, 0, extra.font, paint);
        canvas->sk->restore();
    } else {
        canvas->sk->drawSimpleText(utf8, utf8_len, SkTextEncoding::kUTF8, draw_x, draw_y, extra.font, paint);
    }
    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}

extern "C" FGStatus fg_canvas_measure_text(
    FGCanvas* canvas,
    const char* utf8,
    uint32_t utf8_len,
    FGTextMetrics* out_metrics,
    FGError* out_error
) {
    if (canvas == nullptr || utf8 == nullptr || out_metrics == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "measureText args invalid");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    CanvasExtra& extra = fgExtra(canvas);
    ensureFont(extra);
    SkRect bounds = SkRect::MakeEmpty();
    const float width = extra.font.measureText(utf8, utf8_len, SkTextEncoding::kUTF8, &bounds);
    out_metrics->width = width;
    out_metrics->actual_bounding_box_left = -bounds.left();
    out_metrics->actual_bounding_box_right = bounds.right();
    out_metrics->actual_bounding_box_ascent = -bounds.top();
    out_metrics->actual_bounding_box_descent = bounds.bottom();
    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}
