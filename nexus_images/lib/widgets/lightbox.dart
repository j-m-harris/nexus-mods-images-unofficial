import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/nexus_image.dart';

class LightboxView extends StatelessWidget {
  final NexusImage image;

  const LightboxView({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    final dateStr = image.createdAt != null
        ? _formatDate(image.createdAt!)
        : '';

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Column(
                children: [
                  // Image
                  Expanded(
                    child: Center(
                      child: InteractiveViewer(
                        child: CachedNetworkImage(
                          imageUrl: image.url,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFD35400),
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Color(0xFF888888),
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Info panel
                  GestureDetector(
                    onTap: () {}, // Prevent closing when tapping info
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.black.withValues(alpha: 0.8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            image.displayTitle,
                            style: const TextStyle(
                              color: Colors.white,
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
                              color: Color(0xFFCCCCCC),
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
                                color: Color(0xFFAAAAAA),
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
            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
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
          color: Color(0xFFD35400),
          fontSize: 13,
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFFD35400),
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
