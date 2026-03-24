import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/nexus_image.dart';

class ImageCard extends StatelessWidget {
  final NexusImage image;
  final VoidCallback onTap;

  const ImageCard({super.key, required this.image, required this.onTap});

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
                    colors: [Color(0xFFD35400), Color(0xFFE67E22)],
                  ),
                  border: Border.all(color: const Color(0xFF2A2A4A), width: 1),
                ),
                child: image.ownerAvatar != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: image.ownerAvatar!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.white, size: 20),
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
                        color: Color(0xFFE0E0E0),
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
                          color: Color(0xFF888888),
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
                  color: Color(0xFF666666),
                  fontSize: 12,
                ),
              ),
              // More menu
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showMoreMenu(context),
                child: const Icon(Icons.more_vert,
                    color: Color(0xFF888888), size: 20),
              ),
            ],
          ),
        ),

        // --- Full-width image ---
        GestureDetector(
          onTap: onTap,
          onDoubleTap: () {}, // Could add "like" animation later
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
              imageUrl: image.thumbnailUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) => Container(
                color: const Color(0xFF0F0F23),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFD35400),
                    ),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFF0F0F23),
                child:
                    const Icon(Icons.broken_image, color: Color(0xFF888888)),
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
                  color: Color(0xFFE0E0E0), size: 22),
              const SizedBox(width: 6),
              Text(
                '${image.views}',
                style: const TextStyle(
                    color: Color(0xFFE0E0E0), fontSize: 14),
              ),
              const SizedBox(width: 18),
              const Icon(Icons.star_border_rounded,
                  color: Color(0xFFE0E0E0), size: 22),
              const SizedBox(width: 6),
              Text(
                '${image.rating}',
                style: const TextStyle(
                    color: Color(0xFFE0E0E0), fontSize: 14),
              ),
              const Spacer(),
              if (image.categoryName != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF2A2A4A)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    image.categoryName!,
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 11),
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
                    color: Color(0xFFD35400), size: 20),
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
              style: const TextStyle(fontSize: 13, color: Color(0xFFE0E0E0)),
              children: [
                TextSpan(
                  text: '${image.ownerName ?? 'Unknown'} ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: image.displayTitle,
                  style: const TextStyle(color: Color(0xFFCCCCCC)),
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
              style:
                  const TextStyle(color: Color(0xFF888888), fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        const SizedBox(height: 4),

        // --- Divider between posts ---
        const Divider(color: Color(0xFF2A2A4A), height: 1, thickness: 0.5),
      ],
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
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
                color: const Color(0xFF2A2A4A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (image.siteUrl != null)
              ListTile(
                leading: const Icon(Icons.open_in_new,
                    color: Color(0xFFD35400)),
                title: const Text('View on Nexus Mods',
                    style: TextStyle(color: Color(0xFFE0E0E0))),
                onTap: () {
                  Navigator.pop(ctx);
                  launchUrl(Uri.parse(image.siteUrl!),
                      mode: LaunchMode.externalApplication);
                },
              ),
            ListTile(
              leading:
                  const Icon(Icons.fullscreen, color: Color(0xFFD35400)),
              title: const Text('View Full Image',
                  style: TextStyle(color: Color(0xFFE0E0E0))),
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
