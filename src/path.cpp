//! Native Graphite path ops for Canvas 2D.

#include "canvas_runtime.h"

#include "include/core/SkCanvas.h"
#include "include/core/SkPath.h"
#include "include/core/SkPaint.h"

extern "C" void fg_canvas_begin_path(FGCanvas* canvas) {
    if (canvas == nullptr) return;
    fgExtra(canvas).path.reset();
}

extern "C" void fg_canvas_close_path(FGCanvas* canvas) {
    if (canvas == nullptr) return;
    fgExtra(canvas).path.close();
}

extern "C" void fg_canvas_move_to(FGCanvas* canvas, float x, float y) {
    if (canvas == nullptr) return;
    fgExtra(canvas).path.moveTo(x, y);
}

extern "C" void fg_canvas_line_to(FGCanvas* canvas, float x, float y) {
    if (canvas == nullptr) return;
    fgExtra(canvas).path.lineTo(x, y);
}

extern "C" void fg_canvas_quadratic_curve_to(
    FGCanvas* canvas,
    float cpx,
    float cpy,
    float x,
    float y
) {
    if (canvas == nullptr) return;
    fgExtra(canvas).path.quadTo(cpx, cpy, x, y);
}

extern "C" void fg_canvas_bezier_curve_to(
    FGCanvas* canvas,
    float cp1x,
    float cp1y,
    float cp2x,
    float cp2y,
    float x,
    float y
) {
    if (canvas == nullptr) return;
    fgExtra(canvas).path.cubicTo(cp1x, cp1y, cp2x, cp2y, x, y);
}

extern "C" void fg_canvas_arc(
    FGCanvas* canvas,
    float x,
    float y,
    float radius,
    float start_angle,
    float end_angle,
    uint32_t counterclockwise
) {
    if (canvas == nullptr || radius <= 0.f) return;
    const float sweep = counterclockwise
        ? (start_angle - end_angle)
        : (end_angle - start_angle);
    const float start_deg = SkRadiansToDegrees(start_angle);
    float sweep_deg = SkRadiansToDegrees(sweep);
    if (counterclockwise) {
        if (sweep_deg > 0) sweep_deg = -sweep_deg;
    } else {
        if (sweep_deg < 0) sweep_deg = -sweep_deg;
    }
    // Normalize sweeps larger than a full turn.
    if (sweep_deg > 360.f) sweep_deg = 360.f;
    if (sweep_deg < -360.f) sweep_deg = -360.f;

    SkPathBuilder& path = fgExtra(canvas).path;
    SkRect oval = SkRect::MakeLTRB(x - radius, y - radius, x + radius, y + radius);
    // SkPathBuilder::arcTo is unreliable for a full 360°; addOval/addArc fill correctly.
    if (sweep_deg >= 359.9f || sweep_deg <= -359.9f) {
        path.addOval(oval);
        return;
    }
    // HTML canvas: empty path → move to arc start; otherwise connect with a line.
    path.arcTo(oval, start_deg, sweep_deg, /*forceMoveTo=*/false);
}

extern "C" void fg_canvas_rect(FGCanvas* canvas, float x, float y, float w, float h) {
    if (canvas == nullptr) return;
    fgExtra(canvas).path.addRect(SkRect::MakeXYWH(x, y, w, h));
}

extern "C" FGStatus fg_canvas_fill(FGCanvas* canvas, FGError* out_error) {
    if (canvas == nullptr || canvas->sk == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "FGCanvas is null");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    canvas->sk->drawPath(fgExtra(canvas).path.snapshot(), fgFillPaint(canvas));
    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}

extern "C" FGStatus fg_canvas_stroke(FGCanvas* canvas, FGError* out_error) {
    if (canvas == nullptr || canvas->sk == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "FGCanvas is null");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    canvas->sk->drawPath(fgExtra(canvas).path.snapshot(), fgStrokePaint(canvas));
    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}

extern "C" FGStatus fg_canvas_clip(FGCanvas* canvas, FGError* out_error) {
    if (canvas == nullptr || canvas->sk == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "FGCanvas is null");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    canvas->sk->clipPath(fgExtra(canvas).path.snapshot(), SkClipOp::kIntersect, true);
    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}
