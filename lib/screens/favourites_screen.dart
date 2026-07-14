import 'package:flutter/material.dart';

import '../models/feed_layout.dart';
import '../models/nexus_image.dart';
import '../services/favourites_service.dart';
import '../theme.dart';
import '../widgets/image_card.dart';
import '../widgets/image_grid_tile.dart';
import '../widgets/lightbox.dart';
import '../widgets/planetarium_view.dart';

/// The local favourites gallery: the saved images, newest first, shown in
/// whichever layout the user has selected (list, grid or planetarium) — the
/// same [FeedLayout] the main feed uses. A pinned "Favourites" subheader sits
/// below the app bar so it is obvious which view you are on. Rebuilds live from
/// [FavouritesService], so saving or removing an image elsewhere is reflected
/// here immediately. Tapping an image opens the lightbox in favourites mode
/// (confirmable removal).
class FavouritesScreen extends StatelessWidget {
  /// The active listing layout, shared with the feed.
  final FeedLayout layout;

  /// Whether the favourites tab is currently on screen — gates the
  /// planetarium's render loop.
  final bool active;

  const FavouritesScreen({
    super.key,
    required this.layout,
    required this.active,
  });

  void _openLightbox(
    BuildContext context,
    List<NexusImage> favourites,
    NexusImage image,
  ) {
    final index = favourites.indexWhere((img) => img.id == image.id);
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        // A snapshot of the favourites list: a finite local set, so no
        // onRequestMore. Removing an image pops the lightbox (as before), so
        // the snapshot never goes stale on screen.
        pageBuilder: (_, __, ___) => LightboxPager(
          images: favourites,
          initialIndex: index < 0 ? 0 : index,
          fromFavourites: true,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Inside the Scaffold body, MediaQuery padding already accounts for the app
    // bar (extendBodyBehindAppBar) and bottom nav (extendBody), so use it
    // directly — adding kToolbarHeight/nav height here would double-count and
    // leave a gap below the app bar.
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final bottomInset = media.padding.bottom;

    return ListenableBuilder(
      listenable: FavouritesService.instance,
      builder: (context, _) {
        final favourites = FavouritesService.instance.favourites;
        return Column(
          children: [
            SizedBox(height: topInset),
            _Subheader(count: favourites.length),
            Expanded(
              child: favourites.isEmpty
                  ? _EmptyState(bottomInset: bottomInset)
                  : _buildLayout(context, favourites, bottomInset),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLayout(
    BuildContext context,
    List<NexusImage> favourites,
    double bottomInset,
  ) {
    if (layout == FeedLayout.sphere) {
      // Favourites are a finite local list, so there is nothing to page in —
      // PlanetariumView wraps the cursor back to the first image when the list
      // is exhausted.
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: PlanetariumView(
          images: favourites,
          onImageTap: (image) => _openLightbox(context, favourites, image),
          active: active,
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        if (layout == FeedLayout.grid)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 1,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => ImageGridTile(
                  image: favourites[index],
                  onTap: () =>
                      _openLightbox(context, favourites, favourites[index]),
                ),
                childCount: favourites.length,
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => ImageCard(
                image: favourites[index],
                onTap: () =>
                    _openLightbox(context, favourites, favourites[index]),
              ),
              childCount: favourites.length,
            ),
          ),
        SliverToBoxAdapter(child: SizedBox(height: bottomInset + 12)),
      ],
    );
  }
}

/// Pinned header identifying the favourites view, with a live count and — when
/// there are favourites — a "Clear all" action that confirms before wiping them.
class _Subheader extends StatelessWidget {
  final int count;

  const _Subheader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: NexusColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite, size: 18, color: NexusColors.primary),
          const SizedBox(width: 8),
          const Text(
            'Favourites',
            style: TextStyle(
              color: NexusColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(
                color: NexusColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _clearButton(context),
          ],
        ],
      ),
    );
  }

  Widget _clearButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirmClearAll(context),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, size: 18, color: NexusColors.textMuted),
          const SizedBox(width: 4),
          const Text(
            'Clear all',
            style: TextStyle(
              color: NexusColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NexusColors.surface,
        title: const Text(
          'Clear all favourites?',
          style: TextStyle(color: NexusColors.textPrimary),
        ),
        content: const Text(
          'This removes every image from your local favourites. '
          'This cannot be undone.',
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
              'Clear all',
              style: TextStyle(color: NexusColors.primary),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FavouritesService.instance.clear();
    }
  }
}

class _EmptyState extends StatelessWidget {
  final double bottomInset;

  const _EmptyState({required this.bottomInset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
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
