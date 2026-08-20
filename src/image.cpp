//! Native image decode + drawImage + surface composite for Canvas 2D.

#include "canvas_runtime.h"

#include "include/core/SkCanvas.h"
#include "include/core/SkData.h"
#include "include/core/SkImage.h"
#include "include/core/SkPixmap.h"
#include "include/core/SkSamplingOptions.h"
#include "include/gpu/graphite/Image.h"

#include <cstdlib>
#include <cstring>

#if defined(SK_BUILD_FOR_MAC)
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
#endif

extern "C" FGStatus fg_canvas_draw_image_rgba8(
    FGCanvas* canvas,
    const uint8_t* pixels,
    uint32_t src_w,
    uint32_t src_h,
    float sx,
    float sy,
    float sw,
    float sh,
    float dx,
    float dy,
    float dw,
    float dh,
    FGError* out_error
) {
    if (canvas == nullptr || canvas->sk == nullptr || pixels == nullptr ||
        src_w == 0 || src_h == 0) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "drawImage args invalid");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    SkImageInfo info = SkImageInfo::Make(
        static_cast<int>(src_w),
        static_cast<int>(src_h),
        kRGBA_8888_SkColorType,
        kUnpremul_SkAlphaType);
    SkPixmap pixmap(info, pixels, static_cast<size_t>(src_w) * 4);
    sk_sp<SkImage> raster = SkImages::RasterFromPixmap(pixmap, nullptr, nullptr);
    if (!raster) {
        fgSetError(out_error, FG_STATUS_INTERNAL_ERROR, "RasterFromPixmap failed");
        return FG_STATUS_INTERNAL_ERROR;
    }
    sk_sp<SkImage> image = raster;
    if (skgpu::graphite::Recorder* recorder = canvas->sk->recorder()) {
        sk_sp<SkImage> gpu = SkImages::TextureFromImage(recorder, raster.get());
        if (!gpu) {
            fgSetError(out_error, FG_STATUS_INTERNAL_ERROR, "TextureFromImage failed");
            return FG_STATUS_INTERNAL_ERROR;
        }
        image = std::move(gpu);
    }
    const SkRect src = SkRect::MakeXYWH(sx, sy, sw, sh);
    const SkRect dst = SkRect::MakeXYWH(dx, dy, dw, dh);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setAlphaf(fgExtra(canvas).global_alpha);
    canvas->sk->drawImageRect(
        image,
        src,
        dst,
        SkSamplingOptions(SkFilterMode::kLinear),
        &paint,
        SkCanvas::kFast_SrcRectConstraint);
    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}

extern "C" FGStatus fg_surface_draw_surface(
    FGSurface* dst,
    FGSurface* src,
    float alpha,
    FGError* out_error
) {
    if (dst == nullptr || src == nullptr || !dst->surface || !src->surface ||
        dst->canvas.sk == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "draw_surface args invalid");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    sk_sp<SkImage> image = src->surface->makeImageSnapshot();
    if (!image) {
        fgSetError(out_error, FG_STATUS_INTERNAL_ERROR, "makeImageSnapshot failed");
        return FG_STATUS_INTERNAL_ERROR;
    }
    if (skgpu::graphite::Recorder* recorder = dst->canvas.sk->recorder()) {
        if (sk_sp<SkImage> gpu = SkImages::TextureFromImage(recorder, image.get())) {
            image = std::move(gpu);
        }
    }
    SkPaint paint;
    paint.setAntiAlias(true);
    float a = alpha;
    if (a < 0.f) a = 0.f;
    if (a > 1.f) a = 1.f;
    paint.setAlphaf(a);
    dst->canvas.sk->drawImage(image, 0, 0, SkSamplingOptions(SkFilterMode::kNearest), &paint);
    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}

extern "C" FGStatus fg_canvas_draw_surface_image(
    FGCanvas* dst,
    FGSurface* src,
    float sx,
    float sy,
    float sw,
    float sh,
    float dx,
    float dy,
    float dw,
    float dh,
    FGError* out_error
) {
    if (dst == nullptr || dst->sk == nullptr || src == nullptr || !src->surface) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "draw_surface_image args invalid");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    sk_sp<SkImage> image = src->surface->makeImageSnapshot();
    if (!image) {
        fgSetError(out_error, FG_STATUS_INTERNAL_ERROR, "makeImageSnapshot failed");
        return FG_STATUS_INTERNAL_ERROR;
    }
    if (skgpu::graphite::Recorder* recorder = dst->sk->recorder()) {
        if (sk_sp<SkImage> gpu = SkImages::TextureFromImage(recorder, image.get())) {
            image = std::move(gpu);
        }
    }
    const SkRect src_rect = SkRect::MakeXYWH(sx, sy, sw, sh);
    const SkRect dst_rect = SkRect::MakeXYWH(dx, dy, dw, dh);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setAlphaf(fgExtra(dst).global_alpha);
    dst->sk->drawImageRect(
        image,
        src_rect,
        dst_rect,
        SkSamplingOptions(SkFilterMode::kLinear),
        &paint,
        SkCanvas::kFast_SrcRectConstraint);
    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}

#if defined(SK_BUILD_FOR_MAC)
// native-r1 ships Graphite without PNG/JPEG codecs; use ImageIO on macOS.
static bool decodeWithImageIO(
    const uint8_t* encoded,
    uint32_t encoded_len,
    uint8_t** out_pixels,
    uint32_t* out_width,
    uint32_t* out_height
) {
    CFDataRef cf_data = CFDataCreate(kCFAllocatorDefault, encoded, static_cast<CFIndex>(encoded_len));
    if (cf_data == nullptr) return false;
    CGImageSourceRef source = CGImageSourceCreateWithData(cf_data, nullptr);
    CFRelease(cf_data);
    if (source == nullptr) return false;
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, nullptr);
    CFRelease(source);
    if (image == nullptr) return false;

    const size_t w = CGImageGetWidth(image);
    const size_t h = CGImageGetHeight(image);
    if (w == 0 || h == 0 || w > 16384 || h > 16384) {
        CGImageRelease(image);
        return false;
    }

    const size_t nbytes = w * h * 4;
    auto* pixels = static_cast<uint8_t*>(std::malloc(nbytes));
    if (pixels == nullptr) {
        CGImageRelease(image);
        return false;
    }
    std::memset(pixels, 0, nbytes);

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    // macOS bitmap contexts require premultiplied alpha; convert to unpremul RGBA after.
    const CGBitmapInfo bitmap_info =
        static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast) |
        static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big);
    CGContextRef ctx = CGBitmapContextCreate(
        pixels,
        w,
        h,
        8,
        w * 4,
        space,
        bitmap_info);
    CGColorSpaceRelease(space);
    if (ctx == nullptr) {
        std::free(pixels);
        CGImageRelease(image);
        return false;
    }
    CGContextSetBlendMode(ctx, kCGBlendModeCopy);
    CGContextDrawImage(ctx, CGRectMake(0, 0, static_cast<CGFloat>(w), static_cast<CGFloat>(h)), image);
    CGContextRelease(ctx);
    CGImageRelease(image);

    for (size_t i = 0; i < nbytes; i += 4) {
        const uint8_t a = pixels[i + 3];
        if (a == 0) {
            pixels[i] = 0;
            pixels[i + 1] = 0;
            pixels[i + 2] = 0;
        } else if (a < 255) {
            pixels[i] = static_cast<uint8_t>((pixels[i] * 255 + (a / 2)) / a);
            pixels[i + 1] = static_cast<uint8_t>((pixels[i + 1] * 255 + (a / 2)) / a);
            pixels[i + 2] = static_cast<uint8_t>((pixels[i + 2] * 255 + (a / 2)) / a);
        }
    }

    *out_pixels = pixels;
    *out_width = static_cast<uint32_t>(w);
    *out_height = static_cast<uint32_t>(h);
    return true;
}
#endif

extern "C" FGStatus fg_image_decode_rgba8(
    const uint8_t* encoded,
    uint32_t encoded_len,
    uint8_t** out_pixels,
    uint32_t* out_width,
    uint32_t* out_height,
    FGError* out_error
) {
    if (out_pixels != nullptr) *out_pixels = nullptr;
    if (out_width != nullptr) *out_width = 0;
    if (out_height != nullptr) *out_height = 0;
    if (encoded == nullptr || encoded_len == 0 || out_pixels == nullptr ||
        out_width == nullptr || out_height == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "decode args invalid");
        return FG_STATUS_INVALID_ARGUMENT;
    }

#if defined(SK_BUILD_FOR_MAC)
    if (decodeWithImageIO(encoded, encoded_len, out_pixels, out_width, out_height)) {
        fgSetError(out_error, FG_STATUS_OK, nullptr);
        return FG_STATUS_OK;
    }
#endif

    // Fallback for codecs present in the linked Skia archive (e.g. BMP).
    sk_sp<SkData> data = SkData::MakeWithoutCopy(encoded, encoded_len);
    sk_sp<SkImage> image = SkImages::DeferredFromEncodedData(data);
    if (!image) {
        fgSetError(out_error, FG_STATUS_INTERNAL_ERROR, "image decode failed");
        return FG_STATUS_INTERNAL_ERROR;
    }
    const int w = image->width();
    const int h = image->height();
    if (w <= 0 || h <= 0) {
        fgSetError(out_error, FG_STATUS_INTERNAL_ERROR, "decoded image empty");
        return FG_STATUS_INTERNAL_ERROR;
    }
    const size_t nbytes = static_cast<size_t>(w) * static_cast<size_t>(h) * 4;
    auto* pixels = static_cast<uint8_t*>(std::malloc(nbytes));
    if (pixels == nullptr) {
        fgSetError(out_error, FG_STATUS_OUT_OF_MEMORY, "pixel buffer OOM");
        return FG_STATUS_OUT_OF_MEMORY;
    }
    SkImageInfo info = SkImageInfo::Make(w, h, kRGBA_8888_SkColorType, kUnpremul_SkAlphaType);
    if (!image->readPixels(info, pixels, static_cast<size_t>(w) * 4, 0, 0)) {
        std::free(pixels);
        fgSetError(out_error, FG_STATUS_INTERNAL_ERROR, "readPixels failed");
        return FG_STATUS_INTERNAL_ERROR;
    }
    *out_pixels = pixels;
    *out_width = static_cast<uint32_t>(w);
    *out_height = static_cast<uint32_t>(h);
    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}

extern "C" void fg_image_pixels_free(uint8_t* pixels) {
    std::free(pixels);
}
