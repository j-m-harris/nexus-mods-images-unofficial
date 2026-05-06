# Performance & memory audit

Ranked by likely impact (highest → lowest). Not applied — captured here for follow-up.

## 1. Stop the double-decode in `_resolveImageAspect`
**File:** `lib/widgets/image_card.dart:93-105`

A separate `CachedNetworkImageProvider(thumbnailUrl)` is constructed and an `ImageStreamListener` attached purely to read `info.image.width/height`. This decodes the thumbnail a second time in parallel with the visible one.

Options:
- Attach the listener to the displayed image's stream via a shared `ImageProvider` resolve key.
- Read dimensions from the API response if available.
- Drop crop-detection entirely.

## 2. Bundle Inter, drop `google_fonts`
**File:** `lib/theme.dart:75-80`

`GoogleFonts.interTextTheme` fetches font files over HTTPS on first launch and caches them in the app docs dir — adds latency, a network dependency, and an extra decoded font asset.

Fix: bundle the Inter `.ttf` files under `assets/fonts/` and declare them in `pubspec.yaml`. Removes a startup network call and shrinks the dependency tree.

## 3. Bound the Flutter image cache
**File:** `lib/main.dart`

Nothing sets `PaintingBinding.instance.imageCache.maximumSizeBytes` (default 100MB). On a feed of 2–4MP decoded images that fills quickly.

Fix: in `main.dart`, set `maximumSizeBytes` to ~50MB and `maximumSize` to ~80 entries so the cache evicts aggressively before VRAM pressure builds.

## 4. Gate `_upgradeTimer` on viewport visibility
**File:** `lib/widgets/image_card.dart:127-140`

The timer fires for every card built, including off-screen ones in `CustomScrollView`'s `cacheExtent` (default 250px). Fast scrolls queue dozens of full-res precaches simultaneously.

Fix: wrap the card in `VisibilityDetector` (or use a sliver-aware approach) and only start the timer when the card is actually visible.

## 5. Skip `setState` when facets are unchanged
**File:** `lib/screens/home_screen.dart:115`, `:146`

Every page response reassigns `_facets = result.facets`, forcing `FacetsBar` to rebuild even when nothing changed.

Fix: compare list content first; only assign if different.

## 6. Lazy-build `SearchScreen`
**File:** `lib/screens/home_screen.dart:386-407`

The `Stack`/`Offstage` setup builds `SearchScreen` and instantiates its `TextEditingController`s on launch even though the user starts on tab 0.

Fix: wrap the second `Offstage` child in a "build on first activation" pattern (`_searchEverShown ? SearchScreen(...) : SizedBox.shrink()`).

## 7. Add HTTP timeout + cancel on navigation
**File:** `lib/services/nexus_api.dart`

`http.post` has no timeout, and old in-flight requests aren't aborted when the user changes filters — `_fetchGeneration` ignores the response but the bytes still arrive and parse.

Fix: use `http.Client` with a timeout, or switch to `package:dio` for cancellation tokens.

## 8. Drop `Hero` from cards that won't be tapped
**File:** `lib/widgets/image_card.dart:297`

Every card declares a `Hero` even though only the tapped one ever transitions. Hero adds an extra `OverlayEntry` during navigation and tracks each tagged subtree.

Fix: only attach `Hero` opportunistically (e.g. on hover/press) — or accept the cost if lightbox transitions matter more.

## 9. Narrow `MediaQuery` subscriptions
**Files:** `lib/widgets/image_card.dart` (build), `lib/screens/home_screen.dart:469`

`MediaQuery.of(context)` subscribes the widget to *all* MediaQuery changes (orientation, text scale, viewInsets, etc.).

Fix: use `MediaQuery.sizeOf(context)`, `MediaQuery.paddingOf(context)`, `MediaQuery.devicePixelRatioOf(context)` to subscribe only to what's needed — fewer rebuilds on keyboard show, rotation, etc.

## 10. `_loadGames` blocks startup with no cache
**File:** `lib/services/nexus_api.dart` (`loadGames`)

The full games JSON is fetched every cold start.

Fix: cache the response on disk (last-modified or simple TTL) so repeat launches are instant.

---

The first three would have the biggest real-world effect on the device-rendering issue chased through April–May 2026.
