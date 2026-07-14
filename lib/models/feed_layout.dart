/// The available layouts for image listings — used by both the main feed and
/// the favourites view.
enum FeedLayout {
  list('list'),
  grid('grid'),
  sphere('sphere');

  /// Stable token stored in preferences (enum names could be renamed).
  final String storageValue;

  const FeedLayout(this.storageValue);
}
