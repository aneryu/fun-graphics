//! Canvas 2D runtime extras shared by bridge + incremental v2 objects.
//! FGCanvas / FGSurface layout must match published native-r* objects.

#pragma once

#include "fun_graphics.h"

#include "include/core/SkCanvas.h"
#include "include/core/SkFont.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPath.h"
#include "include/core/SkPathBuilder.h"
#include "include/core/SkSurface.h"

#include <cstdint>
#include <cstring>
#include <unordered_map>
#include <vector>

// Layout locked to native-r1 bridge objects.
struct FGCanvas {
    SkCanvas* sk = nullptr;
    SkPaint fill;
};

struct CanvasExtra {
    SkPaint stroke;
    SkPathBuilder path;
    float global_alpha = 1.f;
    float line_width = 1.f;
    std::vector<float> line_dash;
    float line_dash_offset = 0.f;
    sk_sp<SkFontMgr> font_mgr;
    SkFont font;
    uint32_t text_align = 0;
    uint32_t text_baseline = 0;
    bool stroke_inited = false;
    struct GState {
        SkPaint fill;
        SkPaint stroke;
        float global_alpha = 1.f;
        float line_width = 1.f;
        std::vector<float> line_dash;
        float line_dash_offset = 0.f;
        SkFont font;
        uint32_t text_align = 0;
        uint32_t text_baseline = 0;
    };
    std::vector<GState> gstate;
};

inline std::unordered_map<FGCanvas*, CanvasExtra>& fgCanvasExtras() {
    static std::unordered_map<FGCanvas*, CanvasExtra> extras;
    return extras;
}

inline CanvasExtra& fgExtra(FGCanvas* canvas) {
    CanvasExtra& extra = fgCanvasExtras()[canvas];
    if (!extra.stroke_inited) {
        extra.stroke.setAntiAlias(true);
        extra.stroke.setStyle(SkPaint::kStroke_Style);
        extra.stroke.setStrokeWidth(extra.line_width);
        extra.stroke.setColor4f(SkColor4f{0, 0, 0, 1}, nullptr);
        extra.stroke_inited = true;
    }
    return extra;
}

inline void fgDropExtra(FGCanvas* canvas) {
    if (canvas == nullptr) return;
    fgCanvasExtras().erase(canvas);
}

struct FGSurface {
    void* context = nullptr; // FGContext* in full bridge
    sk_sp<SkSurface> surface;
    FGCanvas canvas;
};

inline void fgSetError(FGError* out_error, FGStatus code, const char* message) {
    if (out_error == nullptr) return;
    out_error->code = code;
    out_error->message = message;
    out_error->message_length = message == nullptr
        ? 0
        : static_cast<uint32_t>(std::strlen(message));
}

inline SkPaint fgFillPaint(FGCanvas* canvas) {
    CanvasExtra& extra = fgExtra(canvas);
    SkPaint paint = canvas->fill;
    SkColor4f c = paint.getColor4f();
    c.fA *= extra.global_alpha;
    paint.setColor4f(c, nullptr);
    return paint;
}

inline SkPaint fgStrokePaint(FGCanvas* canvas) {
    CanvasExtra& extra = fgExtra(canvas);
    SkPaint paint = extra.stroke;
    paint.setStrokeWidth(extra.line_width);
    SkColor4f c = paint.getColor4f();
    c.fA *= extra.global_alpha;
    paint.setColor4f(c, nullptr);
    return paint;
}
