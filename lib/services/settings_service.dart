import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  SharedPreferences? _prefs;
  AdultContentMode _adultMode = AdultContentMode.blur;

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
  }

  AdultContentMode get adultMode => _adultMode;

  Future<void> setAdultMode(AdultContentMode mode) async {
    if (mode == _adultMode) return;
    _adultMode = mode;
    notifyListeners();
    await _prefs?.setString(_adultModeKey, mode.storageValue);
  }

  /// Whether feed/search requests should include adult images at all.
  bool get includeAdultInFeed => _adultMode != AdultContentMode.hide;

  /// Whether an adult image that is on screen sits behind the veil: the
  /// tap-to-reveal blur on cards/tiles/lightbox, or the blur baked into
  /// planetarium tile textures (which have no per-tile reveal — tapping one
  /// opens the lightbox, where the reveal lives).
  bool get blurAdult => _adultMode != AdultContentMode.show;
}
