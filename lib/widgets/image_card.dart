import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/nexus_image.dart';
import '../services/image_aspect_cache.dart';
import '../theme.dart';

class ImageCard extends StatefulWidget {
  final NexusImage image;
  final VoidCallback onTap;
  final ValueChanged<String>? onCategoryTap;
  final ValueChanged<String>? onGameTap;

  const ImageCard({
    super.key,
    required this.image,
    required this.onTap,
    this.onCategoryTap,
    this.onGameTap,
  });

  @override
  State<ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<ImageCard> {
  static const double _cardAspect = 16 / 9;
  static const double _cropThreshold = 0.9;

  bool _fullResReady = false;
  Timer? _upgradeTimer;
  double? _imageAspect;
  ImageStream? _ratioStream;
  ImageStreamListener? _ratioListener;
  TapGestureRecognizer? _authorTap;
  TapGestureRecognizer? _gameTap;
  bool _aspectInitialized = false;
  int? _decodeWidth;

  @override
  void initState() {
    super.initState();
    _bindAuthorTap();
    _bindGameTap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.of(context);
    _decodeWidth = (mq.size.width * mq.devicePixelRatio).round();
    if (!_aspectInitialized) {
      _aspectInitialized = true;
      _resolveImageAspect();
    }
  }

  @override
  void didUpdateWidget(ImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.id != widget.image.id) {
      _fullResReady = false;
      _imageAspect = null;
      _upgradeTimer?.cancel();
      _upgradeTimer = null;
      _detachRatioListener();
      _authorTap?.dispose();
      _authorTap = null;
      _gameTap?.dispose();
      _gameTap = null;
      _resolveImageAspect();
      _bindAuthorTap();
      _bindGameTap();
    } else if (oldWidget.onGameTap != widget.onGameTap) {
      _gameTap?.dispose();
      _gameTap = null;
      _bindGameTap();
    }
  }

  void _bindAuthorTap() {
    if (widget.image.ownerMemberId == null) return;
    _authorTap = TapGestureRecognizer()..onTap = _openAuthorProfile;
  }

  void _openAuthorProfile() {
    final memberId = widget.image.ownerMemberId;
    if (memberId == null) return;
    launchUrl(
      Uri.parse('https://www.nexusmods.com/users/$memberId'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _bindGameTap() {
    final domain = widget.image.gameDomain;
    final cb = widget.onGameTap;
    if (domain == null || cb == null) return;
    _gameTap = TapGestureRecognizer()..onTap = () => cb(domain);
  }

  void _resolveImageAspect() {
    final cached = imageAspectCache[widget.image.id];
    if (cached != null) {
      _imageAspect = cached;
      return;
    }
    final provider = CachedNetworkImageProvider(
      widget.image.thumbnailUrl,
      maxWidth: _decodeWidth,
    );
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final ratio = info.image.width / info.image.height;
      imageAspectCache[widget.image.id] = ratio;
      setState(() {
        _imageAspect = ratio;
      });
    });
    stream.addListener(listener);
    _ratioStream = stream;
    _ratioListener = listener;
  }

  void _detachRatioListener() {
    if (_ratioStream != null && _ratioListener != null) {
      _ratioStream!.removeListener(_ratioListener!);
    }
    _ratioStream = null;
    _ratioListener = null;
  }

  bool get _isCropped {
    final aspect = _imageAspect;
    if (aspect == null) return false;
    final ratio = aspect < _cardAspect
        ? aspect / _cardAspect
        : _cardAspect / aspect;
    return ratio < _cropThreshold;
  }

  bool get _cropsHorizontally =>
      _imageAspect != null && _imageAspect! > _cardAspect;

  void _startUpgradeTimer() {
    if (_fullResReady) return;
    if (_upgradeTimer != null && _upgradeTimer!.isActive) return;
    _upgradeTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final provider = CachedNetworkImageProvider(
        widget.image.url,
        maxWidth: _decodeWidth,
      );
      precacheImage(provider, context).then((_) {
        if (mounted) setState(() => _fullResReady = true);
      }).catchError((_) {});
    });
  }

  void _onVisibility(VisibilityInfo info) {
    if (_fullResReady) return;
    if (info.visibleFraction > 0.5) {
      _startUpgradeTimer();
    } else if (info.visibleFraction < 0.05) {
      _upgradeTimer?.cancel();
      _upgradeTimer = null;
    }
  }

  @override
  void dispose() {
    _upgradeTimer?.cancel();
    _detachRatioListener();
    _authorTap?.dispose();
    _gameTap?.dispose();
    super.dispose();
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

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 365) return '${diff.inDays ~/ 365}y';
      if (diff.inDays > 30) return '${diff.inDays ~/ 30}mo';
      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return 'now';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final decodeWidth = _decodeWidth;

    return VisibilityDetector(
      key: Key('image-card-${image.id}'),
      onVisibilityChanged: _onVisibility,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // --- User header row ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: image.ownerMemberId == null
                    ? null
                    : _openAuthorProfile,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [NexusColors.primary, NexusColors.primaryLight],
                    ),
                    border: Border.all(color: NexusColors.border, width: 1),
                  ),
                  child: image.ownerAvatar != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: image.ownerAvatar!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.person,
                              color: NexusColors.textPrimary,
                              size: 14,
                            ),
                          ),
                        )
                      : Icon(Icons.person,
                          color: NexusColors.textPrimary, size: 14),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 13, color: NexusColors.textPrimary),
                    children: [
                      TextSpan(
                        text: image.ownerName ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        recognizer: _authorTap,
                      ),
                      if (image.gameName != null) ...[
                        const TextSpan(
                          text: ' · ',
                          style: TextStyle(color: NexusColors.textMuted),
                        ),
                        TextSpan(
                          text: image.gameName!,
                          style: const TextStyle(
                              color: NexusColors.textMuted),
                          recognizer: _gameTap,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Icon(Icons.visibility_outlined,
                  color: NexusColors.textSecondary, size: 16),
              const SizedBox(width: 4),
              Text(
                _formatNumber(image.views),
                style: const TextStyle(
                    color: NexusColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 10),
              Icon(Icons.star_outline,
                  color: NexusColors.textSecondary, size: 16),
              const SizedBox(width: 4),
              Text(
                '${image.rating}',
                style: const TextStyle(
                    color: NexusColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 10),
              Icon(Icons.schedule,
                  color: NexusColors.textSecondary, size: 16),
              const SizedBox(width: 4),
              Text(
                _timeAgo(image.createdAt),
                style: const TextStyle(
                  color: NexusColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // --- Full-width image (silently upgrades to full res) ---
        GestureDetector(
          onTap: widget.onTap,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail (always present)
                Hero(
                  tag: 'image-${image.id}',
                  child: CachedNetworkImage(
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
                ),
                // Full-res overlay (fades in when ready)
                AnimatedOpacity(
                  opacity: _fullResReady ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: _fullResReady
                      ? CachedNetworkImage(
                          imageUrl: image.url,
                          fit: BoxFit.cover,
                          memCacheWidth: decodeWidth,
                        )
                      : const SizedBox.shrink(),
                ),
                if (_isCropped)
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: _cropsHorizontally
                              ? Alignment.centerLeft
                              : Alignment.topCenter,
                          end: _cropsHorizontally
                              ? Alignment.centerRight
                              : Alignment.bottomCenter,
                          stops: const [0.0, 0.22, 0.78, 1.0],
                          colors: [
                            Colors.black.withValues(alpha: 0.9),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (image.adult)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(NexusRadii.small),
                      ),
                      child: const Text(
                        'ADULT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // --- Action bar ---
        Padding(
          padding: image.displayDescriptionInline != null &&
                  image.displayDescriptionInline!.isNotEmpty
              ? const EdgeInsets.fromLTRB(12, 8, 12, 2)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  image.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: NexusColors.warmTan,
                  ),
                ),
              ),
              if (image.categoryName != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: widget.onCategoryTap == null
                      ? null
                      : () => widget.onCategoryTap!(image.categoryName!),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: NexusColors.border),
                      borderRadius: BorderRadius.circular(NexusRadii.pill),
                    ),
                    child: Text(
                      image.categoryName!,
                      style: const TextStyle(
                          color: NexusColors.textMuted, fontSize: 11),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  if (image.siteUrl != null) {
                    launchUrl(Uri.parse(image.siteUrl!),
                        mode: LaunchMode.externalApplication);
                  }
                },
                child: Icon(Icons.open_in_new,
                    color: NexusColors.primary, size: 16),
              ),
            ],
          ),
        ),

        if (image.displayDescriptionInline != null &&
            image.displayDescriptionInline!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              image.displayDescriptionInline!,
              style: const TextStyle(
                  color: NexusColors.textMuted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Container(height: 6, color: NexusColors.imagePlaceholder),
      ],
    ),
    );
  }

}
