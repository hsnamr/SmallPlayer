//
//  SPFFmpegBackend.h
//  SmallPlayer
//
//  Thin C API on top of FFmpeg (libavformat, libavcodec, libavutil, libswscale)
//  for opening a media file and decoding video frames to RGB24.
//

#ifndef SPFFmpegBackend_h
#define SPFFmpegBackend_h

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SPFFContext SPFFContext;

/// Open a media file and prepare video decoding. Returns context or NULL on error.
SPFFContext *sp_ff_open(const char *path);

/// Close and free context.
void sp_ff_close(SPFFContext *ctx);

/// Decode next video frame into rgb24 buffer (width * height * 3, row-major).
/// Returns 1 if a frame was decoded, 0 if end of stream, -1 on error.
/// Out params: width, height (frame dimensions); pts_sec (presentation time in seconds).
int sp_ff_decode_next(SPFFContext *ctx, uint8_t *rgb24, size_t rgb24_size,
                      int *out_width, int *out_height, double *pts_sec);

/// Seek to time in seconds (best-effort). Returns 0 on success, -1 on error.
int sp_ff_seek(SPFFContext *ctx, double time_sec);

/// Get video duration in seconds. Returns -1.0 if unknown.
double sp_ff_duration(SPFFContext *ctx);

/// Get current playback position in seconds.
double sp_ff_current_time(SPFFContext *ctx);

#ifdef __cplusplus
}
#endif

#endif /* SPFFmpegBackend_h */
