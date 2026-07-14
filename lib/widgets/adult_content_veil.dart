import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Opaque veil laid over an adult-flagged image while the adult-content
/// setting is off, inviting a tap to reveal. Purely visual — the owning
/// widget handles the reveal tap itself.
///
/// The obscured preview is not a blur of the real pixels: it is a separate
/// tiny decode of the thumbnail ([_decodeWidth] px wide) scaled back up, the
/// way Reddit-style apps veil sensitive media. The detail is destroyed at
/// decode time, so nothing recognisable can survive on large surfaces, and
/// upscaling a 24px image costs nothing next to the per-card saveLayer a
/// BackdropFilter blur needs.
///
/// Mount it whenever the image is gated (adult + blur mode) and drive
/// [revealed]: flipping it fades the veil out (or back in on a re-veil).
/// First build starts at the resting state, so an already-revealed image
/// shows no veil flash, and once fully revealed the veil collapses to
/// nothing.
///
/// Expects to be a child of the image's [Stack].
class AdultContentVeil extends StatelessWidget {
  /// The image's thumbnail URL, re-decoded tiny for the obscured preview.
  final String thumbnailUrl;

  /// Icon-only layout for small grid tiles, where the caption would not fit.
  final bool compact;

  /// Whether the user has revealed the image (veil faded out).
  final bool revealed;

  const AdultContentVeil({
    super.key,
    required this.thumbnailUrl,
    this.compact = false,
    this.revealed = false,
  });

  static const int _decodeWidth = 24;

  @override
  Widget build(BuildContext context) {
    final resting = revealed ? 0.0 : 1.0;
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        // begin only matters on the first build (no entrance animation);
        // later changes to end animate from the current value.
        tween: Tween(begin: resting, end: resting),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        builder: (context, t, child) {
          if (t == 0) return const SizedBox.shrink();
          // Opacity(1.0) paints the child directly, so a resting veil adds no
          // layer; only the 220ms fade does.
          return Opacity(opacity: t, child: child);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Solid base: nothing of the real image may show through before
            // the tiny preview has decoded (or if it fails).
            const ColoredBox(color: NexusColors.imagePlaceholder),
            CachedNetworkImage(
              imageUrl: thumbnailUrl,
              memCacheWidth: _decodeWidth,
              fit: BoxFit.cover,
              // Bilinear upscale smooths the 24px decode into the soft
              // blur-like look.
              filterQuality: FilterQuality.low,
              fadeInDuration: const Duration(milliseconds: 120),
              fadeOutDuration: Duration.zero,
              placeholder: (_, _) => const SizedBox.shrink(),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
            const ColoredBox(color: Color(0x59000000)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    color: NexusColors.textPrimary,
                    size: compact ? 20 : 28,
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Adult content',
                      style: TextStyle(
                        color: NexusColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap to view',
                      style: TextStyle(
                        color: NexusColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
