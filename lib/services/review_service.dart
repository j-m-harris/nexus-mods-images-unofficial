import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for a store review at a moment of demonstrated value: the fifth
/// favourite ever saved. The request is made at most once per install, and the
/// platform (Play's in-app review quota) still decides whether a dialog is
/// actually shown, so the app never nags.
///
/// A singleton like [FavouritesService]; call [init] once at startup before
/// reporting saves.
class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  static const _saveCountKey = 'review.favouriteSaves';
  static const _requestedKey = 'review.requested';
  static const _saveThreshold = 5;

  /// Breathing room between the triggering save and the review dialog, so the
  /// prompt doesn't land mid-interaction while the save state is animating.
  static const _promptDelay = Duration(milliseconds: 1500);

  SharedPreferences? _prefs;

  /// Loads persisted state. Safe to call more than once.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Records one favourite save and, on the [_saveThreshold]th lifetime save,
  /// requests an in-app review. Lifetime saves are counted across removals, so
  /// unfavouriting doesn't reset progress. Best-effort: failures are logged
  /// and never surfaced to the user.
  Future<void> onFavouriteSaved() async {
    final prefs = _prefs;
    if (prefs == null) return;
    if (prefs.getBool(_requestedKey) ?? false) return;
    final saves = (prefs.getInt(_saveCountKey) ?? 0) + 1;
    await prefs.setInt(_saveCountKey, saves);
    if (saves < _saveThreshold) return;
    // Mark as requested before asking: even if the platform declines to show
    // the dialog we must not retry, per the in-app review guidelines.
    await prefs.setBool(_requestedKey, true);
    await Future<void>.delayed(_promptDelay);
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (e) {
      debugPrint('In-app review request failed: $e');
    }
  }
}
