import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/nexus_image.dart';
import '../theme.dart';

class LightboxView extends StatelessWidget {
  final NexusImage image;

  const LightboxView({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        image.createdAt != null ? _formatDate(image.createdAt!) : '';

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: InteractiveViewer(
                        child: CachedNetworkImage(
                          imageUrl: image.url,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(
                              color: NexusColors.primary,
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: NexusColors.textMuted,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: NexusColors.background.withValues(alpha: 0.9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
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
                          const SizedBox(height: 6),
                          Text(
                            [
                              image.gameName ?? '',
                              'by ${image.ownerName ?? 'Unknown'}',
                              dateStr,
                              '${image.views} views',
                              '${image.rating} rating',
                            ].where((s) => s.isNotEmpty).join(' · '),
                            style: const TextStyle(
                              color: NexusColors.warmTan,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (image.description != null &&
                              image.description!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              image.description!,
                              style: const TextStyle(
                                color: NexusColors.textMuted,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _linkButton('Full Image', image.url),
                              if (image.siteUrl != null) ...[
                                const SizedBox(width: 16),
                                _linkButton(
                                    'View on Nexus Mods', image.siteUrl!),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close,
                    color: NexusColors.textPrimary, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
