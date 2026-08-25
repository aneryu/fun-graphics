//! Native Graphite canvas: fill / stroke / transforms / save-restore.
//! `zig build native` packs this into the nightly object. There is no overlay
//! translation unit — path / text / image live in their own files beside this.

#include "internal.h"

#include "include/core/SkCanvas.h"
#include "include/core/SkColor.h"
#include "include/core/SkPaint.h"
#include "include/core/SkRect.h"
#include "include/effects/SkDashPathEffect.h"

extern "C" void fg_canvas_set_fill_style_rgba(
    FGCanvas* canvas,
    float r,
    float g,
    float b,
    float a
) {
    if (canvas == nullptr) return;
    canvas->fill.setAntiAlias(true);
    canvas->fill.setStyle(SkPaint::kFill_Style);
    canvas->fill.setColor4f(SkColor4f{r, g, b, a}, nullptr);
}

extern "C" void fg_canvas_set_stroke_style_rgba(
    FGCanvas* canvas,
    float r,
    float g,
    float b,
    float a
) {
    if (canvas == nullptr) return;
    CanvasExtra& extra = fgExtra(canvas);
    extra.stroke.setAntiAlias(true);
    extra.stroke.setStyle(SkPaint::kStroke_Style);
    extra.stroke.setColor4f(SkColor4f{r, g, b, a}, nullptr);
}

extern "C" void fg_canvas_set_line_width(FGCanvas* canvas, float width) {
    if (canvas == nullptr) return;
    CanvasExtra& extra = fgExtra(canvas);
    extra.line_width = width > 0.f ? width : 1.f;
    extra.stroke.setStrokeWidth(extra.line_width);
}

extern "C" void fg_canvas_set_line_cap(FGCanvas* canvas, uint32_t cap) {
    if (canvas == nullptr) return;
    SkPaint::Cap sk_cap = SkPaint::kButt_Cap;
    if (cap == 1) sk_cap = SkPaint::kRound_Cap;
    else if (cap == 2) sk_cap = SkPaint::kSquare_Cap;
    fgExtra(canvas).stroke.setStrokeCap(sk_cap);
}

extern "C" void fg_canvas_set_line_join(FGCanvas* canvas, uint32_t join) {
    if (canvas == nullptr) return;
    SkPaint::Join sk_join = SkPaint::kMiter_Join;
    if (join == 1) sk_join = SkPaint::kRound_Join;
    else if (join == 2) sk_join = SkPaint::kBevel_Join;
    fgExtra(canvas).stroke.setStrokeJoin(sk_join);
}

extern "C" void fg_canvas_set_miter_limit(FGCanvas* canvas, float limit) {
    if (canvas == nullptr) return;
    fgExtra(canvas).stroke.setStrokeMiter(limit);
}

extern "C" void fg_canvas_set_global_alpha(FGCanvas* canvas, float alpha) {
    if (canvas == nullptr) return;
    if (alpha < 0.f) alpha = 0.f;
    if (alpha > 1.f) alpha = 1.f;
    fgExtra(canvas).global_alpha = alpha;
}

extern "C" void fg_canvas_set_line_dash(
    FGCanvas* canvas,
    const float* dashes,
    uint32_t dash_count,
    float offset
) {
    if (canvas == nullptr) return;
    CanvasExtra& extra = fgExtra(canvas);
    extra.line_dash.clear();
    if (dashes != nullptr && dash_count > 0) {
        extra.line_dash.assign(dashes, dashes + dash_count);
    }
    extra.line_dash_offset = offset;
    if (!extra.line_dash.empty()) {
        extra.stroke.setPathEffect(SkDashPathEffect::Make(
            SkSpan<const SkScalar>(extra.line_dash.data(), extra.line_dash.size()),
            extra.line_dash_offset));
    } else {
        extra.stroke.setPathEffect(nullptr);
    }
}

extern "C" FGStatus fg_canvas_fill_rect(
    FGCanvas* canvas,
    float x,
    float y,
    float w,
    float h,
    FGError* out_error
) {
    if (canvas == nullptr || canvas->sk == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "FGCanvas is null");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    canvas->sk->drawRect(SkRect::MakeXYWH(x, y, w, h), fgFillPaint(canvas));
    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}

extern "C" FGStatus fg_canvas_stroke_rect(
    FGCanvas* canvas,
    float x,
    float y,
    float w,
    float h,
    FGError* out_error
) {
    if (canvas == nullptr || canvas->sk == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "FGCanvas is null");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    canvas->sk->drawRect(SkRect::MakeXYWH(x, y, w, h), fgStrokePaint(canvas));
    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}

extern "C" FGStatus fg_canvas_clear(
    FGCanvas* canvas,
    float r,
    float g,
    float b,
    float a,
    FGError* out_error
) {
    if (canvas == nullptr || canvas->sk == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "FGCanvas is null");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    canvas->sk->clear(SkColor4f{r, g, b, a});
    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}

extern "C" FGStatus fg_canvas_clear_rect(
    FGCanvas* canvas,
    float x,
    float y,
    float w,
    float h,
    FGError* out_error
) {
    if (canvas == nullptr || canvas->sk == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "FGCanvas is null");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    SkPaint paint;
    paint.setAntiAlias(false);
    paint.setStyle(SkPaint::kFill_Style);
    paint.setBlendMode(SkBlendMode::kSrc);
    paint.setColor4f(SkColor4f{0, 0, 0, 0}, nullptr);
    canvas->sk->drawRect(SkRect::MakeXYWH(x, y, w, h), paint);
    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}

extern "C" void fg_canvas_save(FGCanvas* canvas) {
    if (canvas == nullptr || canvas->sk == nullptr) return;
    CanvasExtra& extra = fgExtra(canvas);
    CanvasExtra::GState state;
    state.fill = canvas->fill;
    state.stroke = extra.stroke;
    state.global_alpha = extra.global_alpha;
    state.line_width = extra.line_width;
    state.line_dash = extra.line_dash;
    state.line_dash_offset = extra.line_dash_offset;
    state.font = extra.font;
    state.text_align = extra.text_align;
    state.text_baseline = extra.text_baseline;
    extra.gstate.push_back(std::move(state));
    canvas->sk->save();
}

extern "C" void fg_canvas_restore(FGCanvas* canvas) {
    if (canvas == nullptr || canvas->sk == nullptr) return;
    CanvasExtra& extra = fgExtra(canvas);
    if (!extra.gstate.empty()) {
        CanvasExtra::GState state = std::move(extra.gstate.back());
        extra.gstate.pop_back();
        canvas->fill = state.fill;
        extra.stroke = state.stroke;
        extra.global_alpha = state.global_alpha;
        extra.line_width = state.line_width;
        extra.line_dash = std::move(state.line_dash);
        extra.line_dash_offset = state.line_dash_offset;
        extra.font = state.font;
        extra.text_align = state.text_align;
        extra.text_baseline = state.text_baseline;
    }
    canvas->sk->restore();
}

extern "C" void fg_canvas_set_transform(
    FGCanvas* canvas,
    float a,
    float b,
    float c,
    float d,
    float e,
    float f
) {
    if (canvas == nullptr || canvas->sk == nullptr) return;
    SkMatrix m = SkMatrix::MakeAll(a, c, e, b, d, f, 0, 0, 1);
    canvas->sk->setMatrix(m);
}

extern "C" void fg_canvas_transform(
    FGCanvas* canvas,
    float a,
    float b,
    float c,
    float d,
    float e,
    float f
) {
    if (canvas == nullptr || canvas->sk == nullptr) return;
    SkMatrix m = SkMatrix::MakeAll(a, c, e, b, d, f, 0, 0, 1);
    canvas->sk->concat(m);
}

extern "C" void fg_canvas_translate(FGCanvas* canvas, float x, float y) {
    if (canvas == nullptr || canvas->sk == nullptr) return;
    canvas->sk->translate(x, y);
}

extern "C" void fg_canvas_rotate(FGCanvas* canvas, float radians) {
    if (canvas == nullptr || canvas->sk == nullptr) return;
    canvas->sk->rotate(SkRadiansToDegrees(radians));
}

extern "C" void fg_canvas_scale(FGCanvas* canvas, float x, float y) {
    if (canvas == nullptr || canvas->sk == nullptr) return;
    canvas->sk->scale(x, y);
}
