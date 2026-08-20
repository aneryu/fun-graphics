//! Native Graphite canvas: fillRect / fillStyle / clear.
//! Compiled by tools/build_bridge.sh, not the default Zig stub module.

#include "internal.h"

#include "include/core/SkCanvas.h"
#include "include/core/SkColor.h"
#include "include/core/SkPaint.h"
#include "include/core/SkRect.h"

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
    canvas->sk->drawRect(SkRect::MakeXYWH(x, y, w, h), canvas->fill);
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
