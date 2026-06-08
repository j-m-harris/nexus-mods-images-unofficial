import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart' show gpuTextureFromImage;
import 'package:flutter_scene/gpu.dart' as gpu;

/// Downloads [url] (reusing cached_network_image's disk/memory cache) and
/// uploads it to a Flutter GPU texture for use as a material's
/// `baseColorTexture`, along with the source image's aspect ratio (width /
/// height) so callers can cover-crop it.
///
/// The image is decoded at most [maxWidth] pixels wide to bound GPU memory.
/// Returns `null` if the image fails to load/decode or the GPU is unavailable,
/// so callers can fall back to a placeholder.
Future<({gpu.Texture texture, double aspect})?> loadGpuTexture(
  String url, {
  int maxWidth = 512,
}) async {
  try {
    final image = await _resolveUiImage(url, maxWidth);
    final texture = await gpuTextureFromImage(image);
    return (texture: texture, aspect: image.width / image.height);
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
