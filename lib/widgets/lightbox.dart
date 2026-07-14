import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/nexus_image.dart';
import '../services/adult_reveal_session.dart';
import '../services/favourites_service.dart';
import '../services/image_aspect_cache.dart';
import '../services/review_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import 'adult_content_veil.dart';

/// Swipeable full-screen viewer: hosts one [LightboxView] per image in a
/// [PageView], so swiping left/right moves through the set the image was
/// opened from (feed or favourites). Paging is suspended while the current
/// image is zoomed in, so drags pan the image instead of changing page.
///
/// When [onRequestMore] is set, approaching the end of [images] asks the
/// owner to fetch the next page; [images] is expected to grow in place, and
/// the pager re-reads its length once the fetch completes, so swiping
/// continues seamlessly into new results.
class LightboxPager extends StatefulWidget {
  final List<NexusImage> images;
  final int initialIndex;

  /// See [LightboxView.fromFavourites]; applies to every page.
  final bool fromFavourites;

  /// Called when the user swipes near the end of [images]. Should complete
  /// when the fetch lands (having appended to [images]); no-op futures are
  /// fine when there is nothing more to load.
  final Future<void> Function()? onRequestMore;

  const LightboxPager({
    super.key,
    required this.images,
    required this.initialIndex,
    this.fromFavourites = false,
    this.onRequestMore,
  });

  @override
  State<LightboxPager> createState() => _LightboxPagerState();
}

class _LightboxPagerState extends State<LightboxPager> {
  /// How close to the end of the list a page change has to be to trigger
  /// [LightboxPager.onRequestMore].
  static const _requestMoreThreshold = 3;

  /// Horizontal fling speed (px/s) that commits to the next/previous page
  /// regardless of how far the drag got. Matches kMinFlingVelocity's feel.
  static const _flingVelocity = 365.0;

  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  bool _requestingMore = false;

  @override
  void initState() {
    super.initState();
    // The opened image may already be near the end of the loaded set.
    _maybeRequestMore(widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _maybeRequestMore(int index) {
    if (widget.onRequestMore == null || _requestingMore) return;
    if (index < widget.images.length - _requestMoreThreshold) return;
    _requestingMore = true;
    widget.onRequestMore!().whenComplete(() {
      // Rebuild so the PageView picks up the grown list.
      if (mounted) setState(() => _requestingMore = false);
    });
  }

  /// Shifts the strip by a drag delta ([dx] > 0 drags towards the previous
  /// page), hard-clamped at the ends.
  void _dragBy(double dx) {
    final position = _pageController.position;
    _pageController.jumpTo(
      (position.pixels - dx)
          .clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  /// Settles the strip on a page once the drag ends: a fling commits to the
  /// neighbour in its direction, anything slower snaps to the nearest page.
  void _settle(double velocityX) {
    final page = _pageController.page;
    if (page == null) return;
    final int target;
    if (velocityX <= -_flingVelocity) {
      target = page.floor() + 1;
    } else if (velocityX >= _flingVelocity) {
      target = page.ceil() - 1;
    } else {
      target = page.round();
    }
    _pageController.animateToPage(
      target.clamp(0, widget.images.length - 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The strip is only ever moved programmatically. Each page's
    // InteractiveViewer always wins the gesture arena over a scrollable's drag
    // recognizer (its pan slop loses the race only on slow drags, so fast
    // flicks would be swallowed) — instead of competing with it, paging is
    // driven from the viewer's own interaction callbacks via _dragBy/_settle.
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      // Pre-builds the neighbouring pages, so their thumbnails start loading
      // before the swipe begins.
      allowImplicitScrolling: true,
      itemCount: widget.images.length,
      onPageChanged: _maybeRequestMore,
      itemBuilder: (context, index) => LightboxView(
        key: ValueKey(widget.images[index].id),
        image: widget.images[index],
        fromFavourites: widget.fromFavourites,
        onPageDragUpdate: _dragBy,
        onPageDragEnd: _settle,
      ),
    );
  }
}

class LightboxView extends StatefulWidget {
  final NexusImage image;

  /// Whether this lightbox was opened from the favourites view. When true, the
  /// favourite action becomes a confirmable "Remove from favourites" (Phase 4);
  /// from the feed it is a plain save/unsave toggle.
  final bool fromFavourites;

  /// Forwards horizontal drag deltas to the hosting [LightboxPager] while the
  /// image is at resting zoom (the pager's PageView never handles gestures
  /// itself — see the note in [_LightboxPagerState.build]).
  final ValueChanged<double>? onPageDragUpdate;

  /// Companion to [onPageDragUpdate]: reports the gesture's end velocity so
  /// the pager can settle on a page.
  final ValueChanged<double>? onPageDragEnd;

  const LightboxView({
    super.key,
    required this.image,
    this.fromFavourites = false,
    this.onPageDragUpdate,
    this.onPageDragEnd,
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
  bool _draggingPager = false;
  ImageStream? _aspectStream;
  ImageStreamListener? _aspectListener;

  /// Whether the image should currently sit behind the adult-content veil.
  /// Reveals are shared via [AdultRevealSession]: an image unblurred on its
  /// card/tile opens here already revealed, while one opened fresh (e.g. from
  /// the planetarium) starts veiled.
  bool get _adultObscured =>
      widget.image.adult &&
      SettingsService.instance.blurAdult &&
      !AdultRevealSession.instance.isRevealed(widget.image.id);

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

  /// Whether the current transform is meaningfully away from identity.
  /// Compared with a tolerance: the double-tap zoom-out animation runs through
  /// [Matrix4Tween], whose decompose/recompose can land an epsilon off exact
  /// identity, and an exact comparison would then read as "still zoomed"
  /// forever, silently disabling page swipes.
  bool get _transformIsZoomed {
    const epsilon = 0.001;
    final m = _transformController.value.storage;
    for (var i = 0; i < 16; i++) {
      final identityValue = i % 5 == 0 ? 1.0 : 0.0;
      if ((m[i] - identityValue).abs() > epsilon) return true;
    }
    return false;
  }

  /// Routes a one-finger drag at resting zoom to the pager. Zoomed images and
  /// multi-touch gestures stay with the InteractiveViewer (pan/pinch); a drag
  /// interrupted by a pinch settles the pager back onto a page.
  void _onInteractionUpdate(ScaleUpdateDetails details) {
    if (widget.onPageDragUpdate == null) return;
    if (details.pointerCount > 1 || _transformIsZoomed) {
      if (_draggingPager) {
        _draggingPager = false;
        widget.onPageDragEnd?.call(0);
      }
      return;
    }
    _draggingPager = true;
    widget.onPageDragUpdate!(details.focalPointDelta.dx);
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    if (!_draggingPager) return;
    _draggingPager = false;
    widget.onPageDragEnd?.call(details.velocity.pixelsPerSecond.dx);
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
    final isZoomedIn = _transformIsZoomed;
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
                    // While veiled, the first tap reveals; afterwards a tap
                    // closes the lightbox as usual.
                    onTap: _adultObscured
                        ? () => setState(
                            () => AdultRevealSession.instance.reveal(widget.image.id))
                        : _closeLightbox,
                    onDoubleTapDown: (details) =>
                        _lastDoubleTapDetails = details,
                    onDoubleTap: _handleDoubleTap,
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      clipBehavior: Clip.none,
                      onInteractionUpdate: _onInteractionUpdate,
                      onInteractionEnd: _onInteractionEnd,
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
                                // revealing previously-cropped parts. Not
                                // mounted while veiled — the original isn't
                                // worth fetching until the user asks to see
                                // it; revealing mounts it and it loads then.
                                if (!_adultObscured)
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
                                if (widget.image.adult &&
                                    SettingsService.instance.blurAdult)
                                  AdultContentVeil(
                                    thumbnailUrl: widget.image.thumbnailUrl,
                                    revealed: !_adultObscured,
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
    final saved = await FavouritesService.instance.toggle(widget.image);
    // A save (not an unsave) is the app's "moment of value" that counts
    // towards the one-time in-app review request.
    if (saved) ReviewService.instance.onFavouriteSaved();
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
