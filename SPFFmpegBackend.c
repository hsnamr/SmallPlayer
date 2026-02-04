//
//  SPFFmpegBackend.c
//  SmallPlayer
//
//  FFmpeg-based video decode (C). Demux + decode video stream, output RGB24.
//

#include "SPFFmpegBackend.h"
#include <stdlib.h>
#include <string.h>

#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libswscale/swscale.h>

struct SPFFContext {
    AVFormatContext *fmt_ctx;
    AVCodecContext *codec_ctx;
    int video_stream_index;
    SwsContext *sws_ctx;
    int last_width;
    int last_height;
    AVFrame *frame;
    AVPacket *pkt;
    double time_base;
    double current_pts_sec;
    int eof;
};

SPFFContext *sp_ff_open(const char *path) {
    SPFFContext *ctx = calloc(1, sizeof(SPFFContext));
    if (!ctx) return NULL;

    ctx->video_stream_index = -1;
    ctx->time_base = 0.0001;
    ctx->current_pts_sec = 0.0;
    ctx->eof = 0;

    ctx->fmt_ctx = avformat_alloc_context();
    if (!ctx->fmt_ctx) goto fail;

    if (avformat_open_input(&ctx->fmt_ctx, path, NULL, NULL) < 0) goto fail;
    if (avformat_find_stream_info(ctx->fmt_ctx, NULL) < 0) goto fail;

    ctx->video_stream_index = av_find_best_stream(ctx->fmt_ctx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    if (ctx->video_stream_index < 0) goto fail;

    const AVStream *stream = ctx->fmt_ctx->streams[ctx->video_stream_index];
    const AVCodec *dec = avcodec_find_decoder(stream->codecpar->codec_id);
    if (!dec) goto fail;

    ctx->codec_ctx = avcodec_alloc_context3(dec);
    if (!ctx->codec_ctx) goto fail;
    if (avcodec_parameters_to_context(ctx->codec_ctx, stream->codecpar) < 0) goto fail;
    if (avcodec_open2(ctx->codec_ctx, dec, NULL) < 0) goto fail;

    ctx->time_base = av_q2d(stream->time_base);
    ctx->frame = av_frame_alloc();
    ctx->pkt = av_packet_alloc();
    if (!ctx->frame || !ctx->pkt) goto fail;

    return ctx;
fail:
    sp_ff_close(ctx);
    return NULL;
}

void sp_ff_close(SPFFContext *ctx) {
    if (!ctx) return;
    if (ctx->sws_ctx) sws_freeContext(ctx->sws_ctx);
    if (ctx->frame) av_frame_free(&ctx->frame);
    if (ctx->pkt) av_packet_free(&ctx->pkt);
    if (ctx->codec_ctx) avcodec_free_context(&ctx->codec_ctx);
    if (ctx->fmt_ctx) avformat_close_input(&ctx->fmt_ctx);
    free(ctx);
}

static int decode_one(SPFFContext *ctx) {
    for (;;) {
        if (av_read_frame(ctx->fmt_ctx, ctx->pkt) < 0) {
            ctx->eof = 1;
            avcodec_send_packet(ctx->codec_ctx, NULL);
            if (avcodec_receive_frame(ctx->codec_ctx, ctx->frame) == 0)
                return 1;
            return 0;
        }
        if (ctx->pkt->stream_index != ctx->video_stream_index) {
            av_packet_unref(ctx->pkt);
            continue;
        }
        int ret = avcodec_send_packet(ctx->codec_ctx, ctx->pkt);
        av_packet_unref(ctx->pkt);
        if (ret == AVERROR(EAGAIN)) continue;
        if (ret < 0) return -1;
        ret = avcodec_receive_frame(ctx->codec_ctx, ctx->frame);
        if (ret == AVERROR(EAGAIN)) continue;
        if (ret == 0) return 1;
        if (ret == AVERROR_EOF) return 0;
        return -1;
    }
}

int sp_ff_decode_next(SPFFContext *ctx, uint8_t *rgb24, size_t rgb24_size,
                      int *out_width, int *out_height, double *pts_sec) {
    if (!ctx || !rgb24 || !out_width || !out_height) return -1;
    int r = decode_one(ctx);
    if (r <= 0) return r;

    int w = ctx->frame->width;
    int h = ctx->frame->height;
    size_t need = (size_t)w * (size_t)h * 3;
    if (rgb24_size < need) return -1;

    *out_width = w;
    *out_height = h;
    if (ctx->frame->pts != AV_NOPTS_VALUE)
        ctx->current_pts_sec = ctx->frame->pts * ctx->time_base;
    if (pts_sec) *pts_sec = ctx->current_pts_sec;

    if (!ctx->sws_ctx || ctx->last_width != w || ctx->last_height != h) {
        if (ctx->sws_ctx) sws_freeContext(ctx->sws_ctx);
        ctx->sws_ctx = sws_getContext(w, h, (enum AVPixelFormat)ctx->frame->format,
                                      w, h, AV_PIX_FMT_RGB24, SWS_BILINEAR, NULL, NULL, NULL);
        if (!ctx->sws_ctx) return -1;
        ctx->last_width = w;
        ctx->last_height = h;
    }

    uint8_t *dst[1] = { rgb24 };
    int dst_stride[1] = { w * 3 };
    sws_scale(ctx->sws_ctx, (const uint8_t *const *)ctx->frame->data, ctx->frame->linesize,
              0, h, dst, dst_stride);
    return 1;
}

int sp_ff_seek(SPFFContext *ctx, double time_sec) {
    if (!ctx) return -1;
    int64_t ts = (int64_t)(time_sec / ctx->time_base);
    if (av_seek_frame(ctx->fmt_ctx, ctx->video_stream_index, ts, AVSEEK_FLAG_BACKWARD) < 0)
        return -1;
    avcodec_flush_buffers(ctx->codec_ctx);
    ctx->eof = 0;
    ctx->current_pts_sec = time_sec;
    return 0;
}

double sp_ff_duration(SPFFContext *ctx) {
    if (!ctx || !ctx->fmt_ctx) return -1.0;
    if (ctx->fmt_ctx->duration != AV_NOPTS_VALUE)
        return (double)ctx->fmt_ctx->duration / (double)AV_TIME_BASE;
    AVStream *st = ctx->fmt_ctx->streams[ctx->video_stream_index];
    if (st->duration != AV_NOPTS_VALUE)
        return st->duration * ctx->time_base;
    return -1.0;
}

double sp_ff_current_time(SPFFContext *ctx) {
    return ctx ? ctx->current_pts_sec : -1.0;
}
