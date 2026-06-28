import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/nexus_image.dart';
import '../services/favourites_service.dart';
import '../services/image_aspect_cache.dart';
import '../theme.dart';

class LightboxView extends StatefulWidget {
  final NexusImage image;

  /// Whether this lightbox was opened from the favourites view. When true, the
  /// favourite action becomes a confirmable "Remove from favourites" (Phase 4);
  /// from the feed it is a plain save/unsave toggle.
  final bool fromFavourites;

  const LightboxView({
    super.key,
    required this.image,
    this.fromFavourites = false,
  });

  @override
  State<LightboxView> createState() => _LightboxViewState();
}

class _LightboxViewState extends State<LightboxView>
    with SingleTickerProviderStateMixin {
  static const double _doubleTapScale = 2.5;

  final TransformationController _transformController =
      TransformationController();
  late final AnimationController _animationController;
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _lastDoubleTapDetails;
  double? _imageAspect;
  bool _canSetState = false;
  ImageStream? _aspectStream;
  ImageStreamListener? _aspectListener;

  @override
  void initState() {
    super.initState();
    _imageAspect = imageAspectCache[widget.image.id];
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformController.value = _zoomAnimation!.value;
        }
      });
    // Frame the image by its real aspect up front. Usually already cached (the
    // grid card and the planetarium both record it); otherwise resolve it from
    // the thumbnail, which is the same aspect as the full image and loads from
    // cache, so the box doesn't reflow when the full image arrives.
    if (_imageAspect == null) _resolveThumbnailAspect();
    _canSetState = true;
  }

  void _resolveThumbnailAspect() {
    final provider = CachedNetworkImageProvider(widget.image.thumbnailUrl);
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      final ratio = info.image.width / info.image.height;
      info.dispose(); // only the dimensions are needed
      imageAspectCache[widget.image.id] = ratio;
      stream.removeListener(listener);
      if (!mounted) return;
      // A cached image can call back synchronously from addListener (still in
      // initState), where setState isn't allowed yet — assign directly then.
      if (_canSetState) {
        setState(() => _imageAspect = ratio);
      } else {
        _imageAspect = ratio;
      }
    });
    stream.addListener(listener);
    _aspectStream = stream;
    _aspectListener = listener;
  }

  void _closeLightbox() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    if (_aspectStream != null && _aspectListener != null) {
      _aspectStream!.removeListener(_aspectListener!);
    }
    _transformController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final isZoomedIn = _transformController.value != Matrix4.identity();
    final Matrix4 endMatrix;
    if (isZoomedIn) {
      endMatrix = Matrix4.identity();
    } else {
      final position = _lastDoubleTapDetails?.localPosition;
      final dx = position == null ? 0.0 : -position.dx * (_doubleTapScale - 1);
      final dy = position == null ? 0.0 : -position.dy * (_doubleTapScale - 1);
      endMatrix = Matrix4.identity()
        ..translateByDouble(dx, dy, 0, 1)
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, _doubleTapScale, 1);
    }

    _zoomAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final dateStr =
        image.createdAt != null ? _formatDate(image.createdAt!) : '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeLightbox();
      },
      child: Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _closeLightbox,
                    onDoubleTapDown: (details) =>
                        _lastDoubleTapDetails = details,
                    onDoubleTap: _handleDoubleTap,
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      clipBehavior: Clip.none,
                      minScale: 1.0,
                      maxScale: 5.0,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _imageAspect ?? (16 / 9),
                          child: Hero(
                            tag: 'image-${image.id}',
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Thumbnail underneath, shown whole (contain)
                                // so no part of the image is cropped away.
                                CachedNetworkImage(
                                  imageUrl: image.thumbnailUrl,
                                  fit: BoxFit.contain,
                                  fadeInDuration: Duration.zero,
                                  fadeOutDuration: Duration.zero,
                                  placeholder: (_, _) => const Center(
                                    child: CircularProgressIndicator(
                                      color: NexusColors.primary,
                                    ),
                                  ),
                                  errorWidget: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                                // Full-res fades in on top at the exact same
                                // framing, so it sharpens in rather than
                                // revealing previously-cropped parts.
                                CachedNetworkImage(
                                  imageUrl: image.url,
                                  fit: BoxFit.contain,
                                  fadeInDuration:
                                      const Duration(milliseconds: 280),
                                  fadeInCurve: Curves.easeOut,
                                  placeholder: (_, _) =>
                                      const SizedBox.shrink(),
                                  errorWidget: (_, _, _) => Icon(
                                    Icons.broken_image_outlined,
                                    color: NexusColors.textMuted,
                                    size: 64,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: NexusColors.background.withValues(alpha: 0.9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          Text(
                            image.displayTitle,
                            style: const TextStyle(
                              color: NexusColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (image.gameName != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: NexusColors.border),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sports_esports,
                                    size: 14,
                                    color: NexusColors.warmTan,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    image.gameName!,
                                    style: const TextStyle(
                                      color: NexusColors.warmTan,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          'by ${image.ownerName ?? 'Unknown'}',
                          dateStr,
                          '${_formatNumber(image.views)} views',
                          '${image.rating} rating',
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: const TextStyle(
                          color: NexusColors.warmTan,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (image.displayDescription != null &&
                          image.displayDescription!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          image.displayDescription!,
                          style: const TextStyle(
                            color: NexusColors.textMuted,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Keep the actions on a single line: under the FittedBox
                      // the Row lays out unconstrained, then scales down to fit
                      // narrow screens rather than wrapping onto a second line.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _favouriteButton(),
                            if (image.siteUrl != null) ...[
                              const SizedBox(width: 20),
                              _iconAction(
                                icon: Icons.share,
                                label: 'Share',
                                onTap: _shareImage,
                              ),
                              const SizedBox(width: 20),
                              _linkButton('View on Nexus Mods', image.siteUrl!),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.close,
                    color: NexusColors.textPrimary, size: 28),
                onPressed: _closeLightbox,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// The favourite action. From the favourites view it is a confirmable
  /// "Remove from favourites"; from the feed it is a save/unsave toggle that
  /// rebuilds live from [FavouritesService] so its state stays in sync if the
  /// same image is (un)favourited elsewhere.
  Widget _favouriteButton() {
    if (widget.fromFavourites) {
      return _iconAction(
        icon: Icons.favorite,
        label: 'Remove favourite',
        onTap: _confirmRemoveFavourite,
      );
    }
    final favourites = FavouritesService.instance;
    return ListenableBuilder(
      listenable: favourites,
      builder: (context, _) {
        final saved = favourites.isFavourite(widget.image.id);
        return _iconAction(
          icon: saved ? Icons.favorite : Icons.favorite_border,
          label: saved ? 'Saved' : 'Save',
          onTap: _toggleFavourite,
        );
      },
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: NexusColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: NexusColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavourite() async {
    await FavouritesService.instance.toggle(widget.image);
  }

  /// Confirms before removing, then removes and closes the lightbox so the user
  /// returns to the favourites grid (the listener drops the image from it).
  Future<void> _confirmRemoveFavourite() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NexusColors.surface,
        title: const Text(
          'Remove from favourites?',
          style: TextStyle(color: NexusColors.textPrimary),
        ),
        content: const Text(
          'This image will be removed from your local favourites.',
          style: TextStyle(color: NexusColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: NexusColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: NexusColors.primary),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FavouritesService.instance.remove(widget.image.id);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _linkButton(String label, String url) {
    return GestureDetector(
      onTap: () => _openUrl(url),
      child: Text(
        label,
        style: const TextStyle(
          color: NexusColors.primary,
          fontSize: 13,
          decoration: TextDecoration.underline,
          decorationColor: NexusColors.primary,
        ),
      ),
    );
  }

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Opens the Android share sheet so the user can send the image's Nexus Mods
  /// page URL to other apps. The title is included for context (and as the email
  /// subject), with the URL on its own line so receiving apps still detect it.
  Future<void> _shareImage() async {
    final url = widget.image.siteUrl;
    if (url == null) return;
    final title = widget.image.displayTitle;
    await SharePlus.instance.share(
      ShareParams(
        text: title.isNotEmpty ? '$title\n$url' : url,
        subject: title.isNotEmpty ? title : null,
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
