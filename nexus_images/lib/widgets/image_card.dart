import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/nexus_image.dart';
import '../theme.dart';

class ImageCard extends StatefulWidget {
  final NexusImage image;
  final VoidCallback onTap;
  final ValueChanged<String>? onCategoryTap;

  const ImageCard({
    super.key,
    required this.image,
    required this.onTap,
    this.onCategoryTap,
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

  @override
  void initState() {
    super.initState();
    _startUpgradeTimer();
    _resolveImageAspect();
    _bindAuthorTap();
  }

  @override
  void didUpdateWidget(ImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.id != widget.image.id) {
      _fullResReady = false;
      _imageAspect = null;
      _upgradeTimer?.cancel();
      _detachRatioListener();
      _authorTap?.dispose();
      _authorTap = null;
      _startUpgradeTimer();
      _resolveImageAspect();
      _bindAuthorTap();
    }
  }

  void _bindAuthorTap() {
    final memberId = widget.image.ownerMemberId;
    if (memberId == null) return;
    _authorTap = TapGestureRecognizer()
      ..onTap = () => launchUrl(
            Uri.parse('https://www.nexusmods.com/users/$memberId'),
            mode: LaunchMode.externalApplication,
          );
  }

  void _resolveImageAspect() {
    final provider = CachedNetworkImageProvider(widget.image.thumbnailUrl);
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() {
        _imageAspect = info.image.width / info.image.height;
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
    _upgradeTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final provider =
          CachedNetworkImageProvider(widget.image.url);
      precacheImage(provider, context).then((_) {
        if (mounted) setState(() => _fullResReady = true);
      }).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _upgradeTimer?.cancel();
    _detachRatioListener();
    _authorTap?.dispose();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- User header row ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Container(
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
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.person,
                            color: NexusColors.textPrimary,
                            size: 14,
                          ),
                        ),
                      )
                    : const Icon(Icons.person,
                        color: NexusColors.textPrimary, size: 14),
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
                      if (image.gameName != null)
                        TextSpan(
                          text: ' · ${image.gameName!}',
                          style: const TextStyle(
                              color: NexusColors.textMuted),
                        ),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.visibility_outlined,
                  color: NexusColors.textSecondary, size: 16),
              const SizedBox(width: 4),
              Text(
                _formatNumber(image.views),
                style: const TextStyle(
                    color: NexusColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.star_border_rounded,
                  color: NexusColors.textSecondary, size: 16),
              const SizedBox(width: 4),
              Text(
                '${image.rating}',
                style: const TextStyle(
                    color: NexusColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 10),
              Text(
                _timeAgo(image.createdAt),
                style: const TextStyle(
                  color: NexusColors.darkBrown,
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
                CachedNetworkImage(
                  imageUrl: image.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: NexusColors.imagePlaceholder,
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: NexusColors.primary,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: NexusColors.imagePlaceholder,
                    child: const Icon(Icons.broken_image,
                        color: NexusColors.textMuted),
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
                        borderRadius: BorderRadius.circular(4),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      borderRadius: BorderRadius.circular(4),
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
                child: const Icon(Icons.open_in_new_rounded,
                    color: NexusColors.primary, size: 20),
              ),
            ],
          ),
        ),

        if (image.displayDescriptionInline != null &&
            image.displayDescriptionInline!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 3),
            child: Text(
              image.displayDescriptionInline!,
              style: const TextStyle(
                  color: NexusColors.textMuted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        const SizedBox(height: 6),
        Container(height: 6, color: NexusColors.imagePlaceholder),
      ],
    );
  }

}
