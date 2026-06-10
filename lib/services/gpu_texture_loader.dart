import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart' show gpuTextureFromImage;
import 'package:flutter_scene/gpu.dart' as gpu;

/// Edge length, in pixels, of the square textures used for planetarium tiles.
/// Every tile renders a centred square crop of its image, so all tile textures
/// share this one size — which is exactly what lets them be pooled and reused
/// (see [loadTileTexture] / [releaseTileTexture]).
const int kTileTextureSize = 384;

/// Freed tile textures, kept for reuse. flutter_gpu exposes no explicit
/// texture-free call — a dropped [gpu.Texture] is reclaimed only when its
/// native finalizer eventually runs — so allocating a fresh texture per tile
/// lets orphans pile up and spike GPU memory under fast panning. Instead,
/// cleared textures are returned here and later re-filled in place with
/// `overwrite`, so the working set is recycled rather than churned. Capped so
/// the pool itself can't grow without bound.
final List<gpu.Texture> _texturePool = <gpu.Texture>[];
const int _maxPooledTextures = 32;

/// Downloads [url] (reusing cached_network_image's disk/memory cache), crops it
/// to a centred [kTileTextureSize]² square, and uploads it to a Flutter GPU
/// texture for use as a material's `baseColorTexture`.
///
/// Returns the texture together with the source image's aspect ratio (width /
/// height) — the tile is square, but callers cache the aspect so the lightbox
/// can frame the full image correctly without a reflow. Reuses a pooled texture
/// when one is available (re-filled via `overwrite`), otherwise allocates a new
/// one. Returns `null` if the image fails to load/decode or the GPU is
/// unavailable, so callers can fall back to a placeholder. Hand a
/// no-longer-visible texture back to [releaseTileTexture] to make it available
/// for reuse.
Future<({gpu.Texture texture, double aspect})?> loadTileTexture(
    String url) async {
  try {
    final info = await _resolveUiImage(url, kTileTextureSize);
    final double aspect;
    final ui.Image square;
    // Crop before disposing: the crop reads the image, and the image cache may
    // hold the only other handle on it.
    try {
      aspect = info.image.width / info.image.height;
      square = await _centreCropSquare(info.image, kTileTextureSize);
    } finally {
      info.dispose();
    }
    try {
      // Reserve a pooled texture synchronously: the isNotEmpty check and the
      // removeLast must not straddle an `await`, or two loads running
      // concurrently could both pass the check and the second would pop an
      // empty pool (throwing, then surfacing as a failed/grey tile).
      final pooled = _texturePool.isNotEmpty ? _texturePool.removeLast() : null;
      if (pooled != null) {
        try {
          final bytes =
              await square.toByteData(format: ui.ImageByteFormat.rawRgba);
          if (bytes == null) {
            _texturePool.add(pooled); // untouched; hand it back for reuse
            return null;
          }
          pooled.overwrite(bytes);
          return (texture: pooled, aspect: aspect);
        } catch (_) {
          // Re-pool the reserved texture before the outer catch swallows the
          // error, or it's orphaned to the GC — the churn the pool exists to
          // prevent. Its contents don't matter; the next reuse overwrites it.
          releaseTileTexture(pooled);
          rethrow;
        }
      }
      return (texture: await gpuTextureFromImage(square), aspect: aspect);
    } finally {
      square.dispose();
    }
  } catch (_) {
    return null;
  }
}

/// Returns a tile texture to the pool for reuse. The texture must be
/// [kTileTextureSize]² (i.e. obtained from [loadTileTexture]) and no longer
/// bound to a rendered material. Over-cap textures are dropped, left to the GC
/// finalizer.
void releaseTileTexture(gpu.Texture texture) {
  if (_texturePool.length < _maxPooledTextures) _texturePool.add(texture);
}

/// Renders the centred maximal square of [source] into a fresh [size]² image,
/// so a non-square source isn't stretched — the long edge is cropped.
Future<ui.Image> _centreCropSquare(ui.Image source, int size) async {
  final w = source.width.toDouble();
  final h = source.height.toDouble();
  final side = w < h ? w : h;
  final src = Rect.fromLTWH((w - side) / 2, (h - side) / 2, side, side);
  final dst = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
      source, src, dst, Paint()..filterQuality = FilterQuality.medium);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(size, size);
  } finally {
    picture.dispose();
  }
}

/// Resolves a network image to a decoded image via the shared
/// cached_network_image cache (same provider the cards use). The caller owns
/// the returned [ImageInfo] and must dispose it, or its handle keeps the
/// decoded image alive even after the image cache evicts it.
Future<ImageInfo> _resolveUiImage(String url, int maxWidth) {
  final completer = Completer<ImageInfo>();
  final provider = CachedNetworkImageProvider(url, maxWidth: maxWidth);
  final stream = provider.resolve(const ImageConfiguration());
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      if (!completer.isCompleted) {
        completer.complete(info);
      } else {
        info.dispose();
      }
    },
    onError: (error, stack) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  return completer.future;
}
