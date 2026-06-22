# Feature: Local Favourites Gallery

Save images to a local, on-device gallery ("favourites"), browse them in a
dedicated view, and remove them — with a confirmation step when removing from
within the favourites lightbox.

Status: **Phase 4 complete (confirmable removal) — feature functionally done; Phase 5 polish/release pending**
Target version: 1.2.0 (minor — new user-facing feature)

## Requirements

- [ ] Save an image to local favourites from the **lightbox** view.
- [ ] Persist favourites locally so they survive app restarts.
- [ ] A way to switch to a **favourites view** to browse saved images.
- [ ] When viewing a favourite in the lightbox, offer a **confirmable** action
      to remove it from favourites.

## Key decisions

- **Persistence: `shared_preferences`, storing full image JSON records** (not
  just IDs, not `sqflite`). A personal favourites list is small, and storing the
  full `NexusImage` lets the favourites gallery render with no API round-trip
  (works offline). Fits the app's existing no-database, vanilla-`setState`
  architecture. _Revisit with `sqflite` only if we later need ordering/queries
  at scale._ Requires adding `toJson()` to `NexusImage` (only `fromJson` exists
  today).
- **State sharing: a `FavouritesService` singleton backed by `ChangeNotifier`**
  (built into Flutter, no new package). Loaded once at startup. The lightbox,
  feed, and favourites view all listen, so a save/remove anywhere stays in sync
  everywhere. Keeps the app's "no external state-management lib" convention.
- **Navigation: a new bottom-nav tab** (`_currentTab == 2`) rendering a
  `FavouritesScreen`, alongside the existing Home/Search tabs (`Offstage` +
  `TickerMode` pattern already in `home_screen.dart`).
- **Lightbox context flag:** `LightboxView` takes a `fromFavourites` bool. When
  `false` (feed/search): a save/unsave toggle. When `true` (favourites view):
  the action is **Remove from favourites** and shows a confirmation dialog
  before removing.

## Architecture / affected files

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `shared_preferences`; bump version to `1.2.0`. |
| `lib/models/nexus_image.dart` | Add `toJson()` to mirror existing `fromJson`. |
| `lib/services/favourites_service.dart` *(new)* | `ChangeNotifier` singleton: load/save to `shared_preferences`, `isFavourite(id)`, `add(image)`, `remove(id)`, `List<NexusImage> get favourites`. |
| `lib/widgets/lightbox.dart` | Add `fromFavourites` param; add save/remove action to the bottom panel action area (next to "View on Nexus Mods"); confirm dialog on remove. |
| `lib/screens/favourites_screen.dart` *(new)* | Grid/list of saved images; tapping opens lightbox with `fromFavourites: true`; empty state. |
| `lib/screens/home_screen.dart` | Init/own the `FavouritesService`; add favourites tab to bottom nav + `Offstage` body block; pass `fromFavourites: false` when opening lightbox from the feed. |
| `CHANGELOG.md` | Add 1.2.0 entry on release. |

## Implementation phases

### Phase 1 — Persistence foundation ✅
- [x] Add `shared_preferences` to `pubspec.yaml`; `flutter pub get`.
- [x] Add `toJson()` to `NexusImage`; verify round-trips with `fromJson`.
      (toJson emits the **nested** shape fromJson reads; round-trip covered by
      `test/favourites_roundtrip_test.dart`.)
- [x] Create `FavouritesService` (load, add, remove, isFavourite, toggle, list,
      notifyListeners). JSON list under key `favourites.v1`, newest-first.
- [x] Initialise the service at startup (`await ...init()` in `main`).

### Phase 2 — Save from lightbox ✅
- [x] Add `fromFavourites` param to `LightboxView` (default `false`).
- [x] Add a save/unsave toggle button to the lightbox action area; reflect
      current state via the service listener. (Heart icon + Save/Saved label,
      wrapped in `ListenableBuilder` on `FavouritesService`, in the bottom panel
      actions row beside "View on Nexus Mods".)
- [x] Wire feed → lightbox to pass `fromFavourites: false` (explicit at the
      call site in `_openLightbox`).

### Phase 3 — Favourites view ✅
- [x] Create `FavouritesScreen` (reuses `ImageGridTile`; newest-first grid via
      `ListenableBuilder` on the service); empty state with prompt.
- [x] Add favourites tab to bottom nav (heart, between Search and Layout) +
      `Offstage`/`TickerMode` body block (tab index 2).
- [x] Open lightbox from this screen with `fromFavourites: true`.
- Note: wrapped the feed and favourites tabs in `HeroMode(enabled: active)` so
  only the visible tab registers `image-<id>` Heroes — without it the two grids
  would throw a duplicate-hero-tag error for any image saved while also in feed.

### Phase 4 — Confirmable removal ✅
- [x] In the lightbox when `fromFavourites == true`, show **Remove from
      favourites** action (filled heart).
- [x] Show a confirmation dialog (Cancel / Remove); on confirm, remove via
      service and pop the lightbox back to the grid.
- [x] feed/favourites views update live via the listener (`ListenableBuilder`
      in `FavouritesScreen` + the save toggle rebuild).

### Phase 5 — Polish & release
- [ ] Verify cross-view sync (save in feed → appears in favourites instantly).
- [ ] `flutter analyze` clean; manual run-through of save → browse → remove.
- [ ] Bump to 1.2.0, update `CHANGELOG.md`, commit.

## Resolved decisions

- **Favourites order: most-recently-saved first.** The service stores newest at
  the top; the view renders in that order.
- **After confirming removal from the favourites lightbox: pop back to the
  grid.** The removed image is gone from the grid on return — no in-lightbox
  paging needed.

## Risks / notes

- Migration: none needed (new key); absent key = empty list.

## Progress log

- 2026-06-22 — Plan drafted; codebase surveyed (lightbox, model, nav, deps).
  No implementation started yet.
- 2026-06-22 — Phase 1 done. Added `shared_preferences`, `NexusImage.toJson()`
  (nested, inverse of `fromJson`), `FavouritesService` (ChangeNotifier
  singleton, newest-first, key `favourites.v1`), startup init in `main`.
  `flutter analyze` clean; round-trip test passing.
- 2026-06-22 — Phase 2 done. `LightboxView` gains `fromFavourites` flag and a
  save/unsave heart toggle (live via `ListenableBuilder` on the service); feed
  opens the lightbox with `fromFavourites: false`. `flutter analyze` clean
  (only pre-existing `unnecessary_underscores` lints remain).
- 2026-06-22 — Phase 3 done. New `FavouritesScreen` (newest-first grid + empty
  state), favourites bottom-nav tab (index 2), opens lightbox with
  `fromFavourites: true`. Added `HeroMode` guard around feed/favourites tabs to
  avoid duplicate hero tags. No analyze errors.
- 2026-06-22 — Phase 4 done. Lightbox in `fromFavourites` mode shows a
  confirmable "Remove from favourites" (AlertDialog → remove → pop to grid).
  `lightbox.dart` analyze clean. Feature is functionally complete end-to-end;
  only Phase 5 (verify + release) remains.
