/// Session-scoped record of which adult images the user has tapped to reveal.
///
/// Shared by the feed card, grid tile and lightbox so a reveal follows the
/// image between surfaces: unblur a card and its lightbox page opens already
/// revealed, while opening the same image fresh (e.g. from the planetarium,
/// which has no per-tile reveal) still starts veiled. Deliberately not
/// persisted — every launch starts fully veiled again.
class AdultRevealSession {
  AdultRevealSession._();

  static final Set<String> _revealedIds = {};

  static bool isRevealed(String imageId) => _revealedIds.contains(imageId);

  static void reveal(String imageId) => _revealedIds.add(imageId);
}
