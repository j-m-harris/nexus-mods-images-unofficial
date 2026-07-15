import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feed_layout.dart';
import 'adult_reveal_session.dart';

/// How adult-flagged images are treated.
enum AdultContentMode {
  /// Excluded from the feed server-side; local copies (favourites) stay
  /// veiled.
  hide('hide'),

  /// Fetched and shown everywhere, but behind a blurred tap-to-reveal veil.
  /// The default.
  blur('blur'),

  /// Shown normally, with only the ADULT badge.
  show('show');

  /// Stable token stored in preferences (enum names could be renamed).
  final String storageValue;

  const AdultContentMode(this.storageValue);
}

/// App-wide user preferences, persisted via [SharedPreferences].
///
/// A [ChangeNotifier] singleton like [FavouritesService]: screens listen and
/// rebuild when a setting changes. Call [init] once at startup before reading
/// any state.
class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _adultModeKey = 'settings.adultContentMode';
  static const _adultConfirmedKey = 'settings.adultConfirmed';
  static const _feedLayoutKey = 'settings.feedLayout';

  SharedPreferences? _prefs;
  AdultContentMode _adultMode = AdultContentMode.blur;
  bool _adultConfirmed = false;
  FeedLayout _feedLayout = FeedLayout.list;

  /// Loads persisted settings. Safe to call more than once; only the first
  /// call reads from disk.
  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs?.getString(_adultModeKey);
    _adultMode = AdultContentMode.values.firstWhere(
      (mode) => mode.storageValue == stored,
      orElse: () => AdultContentMode.blur,
    );
    _adultConfirmed = _prefs?.getBool(_adultConfirmedKey) ?? false;
    final storedLayout = _prefs?.getString(_feedLayoutKey);
    _feedLayout = FeedLayout.values.firstWhere(
      (layout) => layout.storageValue == storedLayout,
      orElse: () => FeedLayout.list,
    );
  }

  /// Whether the user has ever confirmed they are 18+ (see
  /// `ensureAdultConfirmed`). One-shot: once set it is never asked again.
  bool get adultConfirmed => _adultConfirmed;

  Future<void> confirmAdult() async {
    if (_adultConfirmed) return;
    _adultConfirmed = true;
    await _prefs?.setBool(_adultConfirmedKey, true);
  }

  AdultContentMode get adultMode => _adultMode;

  Future<void> setAdultMode(AdultContentMode mode) async {
    if (mode == _adultMode) return;
    _adultMode = mode;
    // Changing mode re-baselines what is gated, so per-image reveals from the
    // previous mode no longer apply.
    AdultRevealSession.instance.clear();
    notifyListeners();
    await _prefs?.setString(_adultModeKey, mode.storageValue);
  }

  /// The listing layout last chosen via the layout button or view menu.
  FeedLayout get feedLayout => _feedLayout;

  Future<void> setFeedLayout(FeedLayout layout) async {
    if (layout == _feedLayout) return;
    _feedLayout = layout;
    notifyListeners();
    await _prefs?.setString(_feedLayoutKey, layout.storageValue);
  }

  /// Whether feed/search requests should include adult images at all.
  bool get includeAdultInFeed => _adultMode != AdultContentMode.hide;

  /// Whether an adult image that is on screen sits behind the veil: the
  /// tap-to-reveal blur on cards/tiles/lightbox, or the blur baked into
  /// planetarium tile textures (which have no per-tile reveal — tapping one
  /// opens the lightbox, where the reveal lives).
  bool get blurAdult => _adultMode != AdultContentMode.show;
}
