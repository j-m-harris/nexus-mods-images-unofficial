import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/nexus_image.dart';
import '../theme.dart';

class ImageCard extends StatelessWidget {
  final NexusImage image;
  final VoidCallback onTap;

  const ImageCard({super.key, required this.image, required this.onTap});

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- User header row ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 36,
                height: 36,
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
                            size: 20,
                          ),
                        ),
                      )
                    : const Icon(Icons.person,
                        color: NexusColors.textPrimary, size: 20),
              ),
              const SizedBox(width: 10),
              // Name + game
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      image.ownerName ?? 'Unknown',
                      style: const TextStyle(
                        color: NexusColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (image.gameName != null)
                      Text(
                        image.gameName!,
                        style: const TextStyle(
                          color: NexusColors.textMuted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Time ago
              Text(
                _timeAgo(image.createdAt),
                style: const TextStyle(
                  color: NexusColors.darkBrown,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showMoreMenu(context),
                child: const Icon(Icons.more_vert,
                    color: NexusColors.textMuted, size: 20),
              ),
            ],
          ),
        ),

        // --- Full-width image ---
        GestureDetector(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
              imageUrl: image.thumbnailUrl,
              fit: BoxFit.cover,
              width: double.infinity,
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
          ),
        ),

        // --- Action bar ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.visibility_outlined,
                  color: NexusColors.textSecondary, size: 22),
              const SizedBox(width: 6),
              Text(
                _formatNumber(image.views),
                style: const TextStyle(
                    color: NexusColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(width: 18),
              const Icon(Icons.star_border_rounded,
                  color: NexusColors.textSecondary, size: 22),
              const SizedBox(width: 6),
              Text(
                '${image.rating}',
                style: const TextStyle(
                    color: NexusColors.textSecondary, fontSize: 14),
              ),
              const Spacer(),
              if (image.categoryName != null)
                Container(
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

        // --- Caption ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 13, color: NexusColors.textPrimary),
              children: [
                TextSpan(
                  text: '${image.ownerName ?? 'Unknown'} ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: image.displayTitle,
                  style: const TextStyle(color: NexusColors.warmTan),
                ),
              ],
            ),
          ),
        ),

        if (image.description != null && image.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 3),
            child: Text(
              image.description!,
              style: const TextStyle(
                  color: NexusColors.textMuted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        const SizedBox(height: 4),
        const Divider(color: NexusColors.border, height: 1, thickness: 0.5),
      ],
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NexusColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NexusColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (image.siteUrl != null)
              ListTile(
                leading:
                    const Icon(Icons.open_in_new, color: NexusColors.primary),
                title: const Text('View on Nexus Mods',
                    style: TextStyle(color: NexusColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  launchUrl(Uri.parse(image.siteUrl!),
                      mode: LaunchMode.externalApplication);
                },
              ),
            ListTile(
              leading:
                  const Icon(Icons.fullscreen, color: NexusColors.primary),
              title: const Text('View Full Image',
                  style: TextStyle(color: NexusColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse(image.url),
                    mode: LaunchMode.externalApplication);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
