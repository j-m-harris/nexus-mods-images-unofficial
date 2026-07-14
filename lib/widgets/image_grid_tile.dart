import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/nexus_image.dart';
import '../services/adult_reveal_session.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import 'adult_content_veil.dart';

/// A lightweight square thumbnail tile for the alternative grid layout.
///
/// Unlike [ImageCard] it shows no metadata and never upgrades to full-res — it
/// is built for fast scanning. Tapping heroes into the lightbox (which shows the
/// full, uncropped image), so cropping the thumbnail to a square is harmless.
class ImageGridTile extends StatefulWidget {
  final NexusImage image;
  final VoidCallback onTap;

  const ImageGridTile({
    super.key,
    required this.image,
    required this.onTap,
  });

  @override
  State<ImageGridTile> createState() => _ImageGridTileState();
}

class _ImageGridTileState extends State<ImageGridTile> {
  /// See [AdultRevealSession]: reveals are keyed by image id and shared with
  /// the card and lightbox.
  bool get _adultObscured =>
      widget.image.adult &&
      SettingsService.instance.blurAdult &&
      !AdultRevealSession.instance.isRevealed(widget.image.id);

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final mq = MediaQuery.of(context);
    // Tiles are roughly a third of the screen wide (3-column grid).
    final decodeWidth = (mq.size.width / 3 * mq.devicePixelRatio).round();

    return GestureDetector(
      // While veiled, the first tap reveals; only then does a tap open the
      // lightbox.
      onTap: _adultObscured
          ? () => setState(() => AdultRevealSession.instance.reveal(widget.image.id))
          : widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The veil lives inside the Hero so a flight of a still-veiled
          // image carries the veil with it instead of flashing the real
          // thumbnail.
          Hero(
            tag: 'image-${image.id}',
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: image.thumbnailUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: decodeWidth,
                  placeholder: (_, __) =>
                      Container(color: NexusColors.imagePlaceholder),
                  errorWidget: (_, __, ___) => Container(
                    color: NexusColors.imagePlaceholder,
                    child: Icon(Icons.broken_image_outlined,
                        color: NexusColors.textMuted),
                  ),
                ),
                if (image.adult && SettingsService.instance.blurAdult)
                  AdultContentVeil(
                    thumbnailUrl: image.thumbnailUrl,
                    compact: true,
                    revealed: !_adultObscured,
                  ),
              ],
            ),
          ),
          if (image.adult)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(NexusRadii.small),
                ),
                child: const Text(
                  'ADULT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
