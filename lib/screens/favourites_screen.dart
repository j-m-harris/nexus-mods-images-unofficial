import 'package:flutter/material.dart';

import '../models/nexus_image.dart';
import '../services/favourites_service.dart';
import '../theme.dart';
import '../widgets/image_grid_tile.dart';
import '../widgets/lightbox.dart';

/// The local favourites gallery: a thumbnail grid of saved images, newest
/// first. Rebuilds live from [FavouritesService], so saving or removing an
/// image elsewhere is reflected here immediately. Tapping a tile opens the
/// lightbox in favourites mode (confirmable removal).
class FavouritesScreen extends StatelessWidget {
  /// Height of the host's bottom nav bar, so the grid clears it (the host
  /// Scaffold uses `extendBody`).
  final double bottomNavHeight;

  const FavouritesScreen({super.key, required this.bottomNavHeight});

  void _openLightbox(BuildContext context, NexusImage image) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) =>
            LightboxView(image: image, fromFavourites: true),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top + kToolbarHeight;
    final bottomInset = media.padding.bottom + bottomNavHeight;

    return ListenableBuilder(
      listenable: FavouritesService.instance,
      builder: (context, _) {
        final favourites = FavouritesService.instance.favourites;

        if (favourites.isEmpty) {
          return _EmptyState(topInset: topInset, bottomInset: bottomInset);
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: topInset)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ImageGridTile(
                    image: favourites[index],
                    onTap: () => _openLightbox(context, favourites[index]),
                  ),
                  childCount: favourites.length,
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: bottomInset + 12)),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final double topInset;
  final double bottomInset;

  const _EmptyState({required this.topInset, required this.bottomInset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_border,
                size: 56,
                color: NexusColors.textMuted,
              ),
              const SizedBox(height: 16),
              const Text(
                'No favourites yet',
                style: TextStyle(
                  color: NexusColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open an image and tap Save to add it to your '
                'local favourites.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NexusColors.textMuted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
