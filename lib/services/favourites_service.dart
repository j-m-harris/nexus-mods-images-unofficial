import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/nexus_image.dart';

/// On-device store of favourited images, persisted via [SharedPreferences] as a
/// JSON list of full [NexusImage] records (so the favourites view renders with
/// no API round-trip). Newest saves are kept at the head of the list.
///
/// A [ChangeNotifier] singleton: the feed, lightbox and favourites view all
/// listen, so a save or removal anywhere is reflected everywhere. Call [init]
/// once at startup before reading any state.
class FavouritesService extends ChangeNotifier {
  FavouritesService._();
  static final FavouritesService instance = FavouritesService._();

  static const _storageKey = 'favourites.v1';

  SharedPreferences? _prefs;
  final List<NexusImage> _favourites = [];
  final Set<String> _ids = {};

  /// Loads persisted favourites. Safe to call more than once; only the first
  /// call reads from disk. An absent or unparseable key yields an empty list.
  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    _load();
  }

  void _load() {
    _favourites.clear();
    _ids.clear();
    final raw = _prefs?.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        final image = NexusImage.fromJson(entry);
        if (_ids.add(image.id)) _favourites.add(image);
      }
    } catch (_) {
      // Corrupt payload — start from an empty list rather than crashing.
      _favourites.clear();
      _ids.clear();
    }
  }

  Future<void> _persist() async {
    final raw = jsonEncode(_favourites.map((img) => img.toJson()).toList());
    await _prefs?.setString(_storageKey, raw);
  }

  /// Favourites, most-recently-saved first. Returns an unmodifiable view.
  List<NexusImage> get favourites => List.unmodifiable(_favourites);

  int get count => _favourites.length;

  bool isFavourite(String id) => _ids.contains(id);

  /// Saves [image] to favourites (newest first). No-op if already saved.
  Future<void> add(NexusImage image) async {
    if (!_ids.add(image.id)) return;
    _favourites.insert(0, image);
    notifyListeners();
    await _persist();
  }

  /// Removes the favourite with [id]. No-op if not present.
  Future<void> remove(String id) async {
    if (!_ids.remove(id)) return;
    _favourites.removeWhere((img) => img.id == id);
    notifyListeners();
    await _persist();
  }

  /// Removes every favourite. No-op if already empty.
  Future<void> clear() async {
    if (_favourites.isEmpty) return;
    _favourites.clear();
    _ids.clear();
    notifyListeners();
    await _persist();
  }

  /// Adds [image] if absent, removes it if present. Returns the new state
  /// (`true` = now a favourite).
  Future<bool> toggle(NexusImage image) async {
    if (isFavourite(image.id)) {
      await remove(image.id);
      return false;
    }
    await add(image);
    return true;
  }
}
