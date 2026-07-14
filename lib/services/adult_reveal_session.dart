import 'package:flutter/foundation.dart';

/// Session-scoped record of which adult images the user has tapped to reveal.
///
/// Shared by the feed card, grid tile, lightbox and planetarium so a reveal
/// follows the image between surfaces — in both directions: unblur a card and
/// its lightbox page opens already revealed; reveal inside the lightbox
/// (e.g. after swiping to a veiled page) and the listing tile behind is
/// unveiled when you return. Deliberately not persisted — every launch starts
/// fully veiled again.
///
/// A [ChangeNotifier] singleton like the services: the listing screens listen
/// so tiles rebuilt behind a route reflect reveals made inside it.
class AdultRevealSession extends ChangeNotifier {
  AdultRevealSession._();
  static final AdultRevealSession instance = AdultRevealSession._();

  final Set<String> _revealedIds = {};

  bool isRevealed(String imageId) => _revealedIds.contains(imageId);

  void reveal(String imageId) {
    if (_revealedIds.add(imageId)) notifyListeners();
  }

  /// Forgets every reveal. Called when the adult-content mode changes:
  /// re-picking a mode is a re-baselining, so previously revealed images go
  /// back behind the veil.
  void clear() {
    if (_revealedIds.isEmpty) return;
    _revealedIds.clear();
    notifyListeners();
  }
}
