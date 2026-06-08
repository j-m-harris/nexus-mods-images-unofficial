import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart' show gpuTextureFromImage;
import 'package:flutter_scene/gpu.dart' as gpu;

/// Downloads [url] (reusing cached_network_image's disk/memory cache) and
/// uploads it to a Flutter GPU texture for use as a material's
/// `baseColorTexture`.
///
/// The image is decoded at most [maxWidth] pixels wide to bound GPU memory —
/// planetarium quads are small on screen, so a thumbnail-sized texture is
/// plenty. Returns `null` if the image fails to load/decode or the GPU is
/// unavailable, so callers can fall back to a placeholder.
Future<gpu.Texture?> loadGpuTexture(String url, {int maxWidth = 384}) async {
  try {
    final image = await _resolveUiImage(url, maxWidth);
    return await gpuTextureFromImage(image);
  } catch (_) {
    return null;
  }
}

/// Resolves a network image to a decoded [ui.Image] via the shared
/// cached_network_image cache (same provider the cards use).
Future<ui.Image> _resolveUiImage(String url, int maxWidth) {
  final completer = Completer<ui.Image>();
  final provider = CachedNetworkImageProvider(url, maxWidth: maxWidth);
  final stream = provider.resolve(const ImageConfiguration());
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete(info.image);
    },
    onError: (error, stack) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  return completer.future;
}
