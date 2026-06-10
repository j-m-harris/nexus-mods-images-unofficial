# Recommendations — June 2026 review

A fresh pass over the whole app (v1.1.0, `planetarium` branch). This deliberately
does **not** repeat what's already tracked: `PERFORMANCE_NOTES.md` items 5–10 are
still open and still worth doing (the facets `setState` skip, lazy `SearchScreen`,
HTTP timeout/cancellation, opportunistic `Hero`, narrowed `MediaQuery`
subscriptions, and a games-list disk cache), and `TODO.md` covers the
minSdk/Vulkan story plus the planetarium polish list. Everything below is new.

Ranked within each section by expected impact.

---

## Performance

### P1. Avatar images decode at full resolution
**File:** `lib/widgets/image_card.dart:241`

The 24×24 avatar `CachedNetworkImage` has no `memCacheWidth`, so each avatar is
decoded at its native size (often 512²+) and held in the image cache at that
size — for a circle 24 logical pixels wide, repeated for every card in the
feed. This is likely the single cheapest memory win left in the list view.

Fix: `memCacheWidth: (24 * devicePixelRatio).round()` (and consider
`maxWidth` on the provider so the disk cache stores the small variant too).

### P2. Pooled tile reuse pays a GPU→CPU readback per tile
**File:** `lib/services/gpu_texture_loader.dart:48-58`

The pooled path does `square.toByteData(rawRgba)` — a synchronous GPU readback
of the freshly rasterised crop — then re-uploads those bytes with `overwrite`.
So every pooled tile crosses the bus twice (render → readback → upload), while
the non-pooled path (`gpuTextureFromImage`) uploads once. Under fast panning
the readbacks stall the raster thread.

Options, in order of preference:
- Skip the `PictureRecorder` round-trip entirely: decode with
  `instantiateImageCodec(targetWidth/Height)` (or keep `_resolveUiImage`),
  then `toByteData` the *decoded* image once and do the centre-crop on the CPU
  byte buffer (row slicing) before `overwrite`. One readback-free path for both
  pooled and fresh textures.
- Or only pool when a readback-free byte source is available, and accept
  allocation churn otherwise.

### P3. Unbounded concurrent tile loads, in arbitrary order
**File:** `lib/widgets/planetarium_view.dart:473-507` (`_recycle`)

When the sphere first shows (or after a feed reset), ~50 faces are inside
`_loadCos` at once and `_loadCellTexture` is fired for all of them in cell-list
order. That means ~50 simultaneous decodes + crops + uploads competing on the
UI/raster threads, and the tiles the user is actually looking at are not
filled first.

Fix: keep a small in-flight counter (e.g. max 4–6 concurrent loads) and each
tick start loads for the unloaded in-view cells with the **highest
`look.dot(center)`** first. Centre tiles pop in immediately, the edge fills in
behind, and the decode burst flattens out. This also makes the existing
`onRequestMore` paging smoother since pages get consumed gradually.

### P4. The idle sphere never stops working
**File:** `lib/widgets/planetarium_view.dart:559-612`

Auto-glide is permanent: after 2 s of no input the camera drifts forever, which
keeps `_dirty` set, so the scene re-renders at 60 Hz indefinitely while the
Sphere tab is open — even face-down on a table. The `_dirty` gating you built
is effectively defeated by the glide.

Fix: stop (or pause) the glide after a bounded period (say 2–3 minutes idle),
and/or hook `WidgetsBindingObserver.didChangeAppLifecycleState` to stop the
ticker when the app is backgrounded — `TickerMode` does not cover the app
going inactive. This pairs with the already-tracked "early-out `_recycle` /
`_animate` when fully idle" TODO item.

### P5. Lightbox decodes the full-resolution original
**File:** `lib/widgets/lightbox.dart:166`

The full-res overlay has no `memCacheWidth`. Nexus originals can be 4K+; a
3840×2160 decode is ~33 MB, which alone consumes two-thirds of the 50 MB cache
budget set in `main.dart` and forces evictions of the whole feed behind it.

You do want extra resolution for the 5× pinch-zoom, but not unbounded: cap at
`screenWidth * dpr * maxScale` (or a fixed ~2560) via `memCacheWidth`. Same
budget, predictable.

### P6. Description HTML/BBCode stripping runs on every build
**File:** `lib/models/nexus_image.dart:71-106`

`displayDescription` / `displayDescriptionInline` run ~12 regex passes per
call, and `ImageCard.build` calls the inline variant up to three times per
build (two condition checks + the `Text`). During a fast scroll that's
hundreds of regex chains per frame on long descriptions.

Fix: compute both once per model instance (`late final String? _inline = …`)
since `NexusImage` is immutable. One-line change, removes the cost entirely.

### P7. `imageAspectCache` grows without bound
**File:** `lib/services/image_aspect_cache.dart`

One `Map<String, double>` entry per image ever seen. Entries are tiny so this
is slow-burn, but an infinite-scroll session plus the planetarium cycling the
feed means it only ever grows. A trivial LRU (or even "clear when > 2000
entries") makes it a non-issue forever. While you're there, give the file a
class with a doc comment — a bare global in a 1-line file is easy to misuse.

---

## Correctness & robustness

### C1. The only test is broken and hits the live network
**File:** `test/widget_test.dart`

`find.text('Nexus Mods Image Browser')` matches nothing — the AppBar renders
"Nexus Mods Images Unofficial" (`home_screen.dart:308`), and `MaterialApp.title`
is not a widget. Worse, pumping `NexusImagesApp` triggers `_performSearch()` and
`_loadGames()`, which issue real HTTP calls in the test environment.

This blocks any meaningful CI. Fix in two steps:
1. Make `NexusApi` an instance (or pass an `http.Client` in) so tests can
   inject a fake — it's currently all-static and unmockable. This also
   unlocks `PERFORMANCE_NOTES.md` item 7 (shared client → connection
   keep-alive across requests, plus timeouts) as the same refactor.
2. Re-point the assertion at text that exists, and add a couple of real cases:
   search resets paging, pagination dedupes by id, error state shows retry.

### C2. Stale aspect-ratio listener can write the wrong cache entry
**File:** `lib/widgets/image_card.dart:105-127`

`_resolveImageAspect`'s `ImageStreamListener` captures `widget.image.id` *at
callback time*, not bind time. If the card is recycled to a new image
(`didUpdateWidget` detaches the old listener — good), the safe path is taken;
but within one binding the listener is also never removed after first fire, so
a multi-frame image (animated thumbnail) keeps calling `setState`. Capture
`final id = widget.image.id;` before resolving, write the cache against that
captured id, and `removeListener` inside the callback (as the lightbox version
already does at `lightbox.dart:55-67`).

### C3. Games lookup failures are invisible
**Files:** `lib/screens/home_screen.dart:80-87`, `:263-273`

If `_loadGames()` fails (offline first launch), `_games` stays empty silently:
the search screen's game picker shows only "All Games", and
`_filterByGameDomain` (tapping a game name on a card) silently does nothing.
Retry on failure (simple backoff or retry on next search-tab open) and/or fall
back to filtering by the tapped card's `gameId`-less domain so the tap isn't a
dead control.

### C4. Pull-to-refresh discards the visible feed
**File:** `lib/screens/home_screen.dart:98-135`

`_performSearch` clears `_images` and flips to the skeleton list immediately,
so a refresh blanks the screen instead of swapping content when the response
lands. Keep the current list rendered while `_loading && _images.isNotEmpty`
(the `RefreshIndicator` already provides the activity signal), and only show
skeletons on a *cold* or filter-changed load.

### C5. Sphere paging stalls when the feed errors
**Files:** `lib/widgets/planetarium_view.dart:506`, `home_screen.dart:137-167`

`_recycle` calls `onRequestMore` every tick while faces are starving, which is
fine because `_loadNextPage` no-ops while `_loadingMore` — but if the page
request *fails*, `_loadingMore` resets and the sphere immediately re-requests,
forever, with no backoff: a tight retry loop against the API on a flaky
connection. Add a short cooldown after a failed page load (e.g. ignore
`onRequestMore` for 5 s).

---

## Code health

- **`_formatNumber` is implemented three times** (`image_card.dart:183`,
  `lightbox.dart:295`, `NexusGame._commaFormat`). Extract one
  `lib/utils/format.dart` and put `_timeAgo` and `_formatDate` there too —
  `_formatDate` currently renders US-style `M/D/Y` for everyone; consider
  `MaterialLocalizations.of(context).formatShortDate` while moving it.
- **Dead conditional**: `home_screen.dart:569-570` — both branches of the
  search-tab icon are `Icons.search`.
- **`createdAt` is a `String`** on the model and parsed (with try/catch) at
  every render. Parse once to `DateTime?` in `fromJson`.
- **Analyzer hygiene**: `flutter analyze` reports 14 infos (13×
  `unnecessary_underscores`, 1× `prefer_final_fields`) — ten minutes to zero.
- **Lint posture**: the project is on stock `flutter_lints` with nothing
  enabled. Given how performance-sensitive this app is, consider adding
  `prefer_const_constructors`, `use_decorated_box`, and
  `avoid_redundant_argument_values`.
- **`home_screen.dart` is doing four jobs** (feed state machine, app bar,
  bottom nav, layout chrome — 744 lines). Extracting the feed
  fetch/paginate/dedupe state into a small controller class would shrink it by
  half and is the precondition for testing C1 properly.

---

## Product / UX

- **Adult content has no gate.** `adult` images render fully with only a badge
  (`image_card.dart:375`, `image_grid_tile.dart:47`) — and in the planetarium,
  with no badge at all. For an app browsing Nexus's live feed this matters for
  store review (Play/App Store both ask). Add a settings toggle (default off →
  blur with tap-to-reveal), and pass an adult filter to the API query if it
  supports one.
- **Layout and sort don't persist.** `_layout`, `_sort`, and the adult toggle
  above belong in `shared_preferences`; cold start always lands on
  list/newest.
- **Accessibility is near-zero.** Nav buttons are bare `GestureDetector`+`Icon`
  with no semantics or tooltips (`home_screen.dart:590-613`); images have no
  `semanticLabel`; the lightbox close affordance is icon-only. A `Semantics`
  pass over nav, cards, and lightbox is cheap and makes TalkBack usable.
- **Planetarium discoverability.** The long-press layout sheet is the only
  hint that the sphere exists. A one-time hint ("drag to look around") overlay
  on first sphere entry would help — the auto-glide partially covers this, but
  only after 2 s of confusion.

---

## Suggested order

1. C1 (testability refactor — unlocks PERF #7 and everything else lands safer)
2. P1 + P5 + P6 (three small, high-leverage decode/CPU wins)
3. P3 + P4 (planetarium load ordering + idle shutdown, alongside the open TODO items)
4. C4 + C5 (refresh UX, paging backoff)
5. Adult-content gate before any store submission
6. P2 (readback-free tile path — biggest planetarium win but needs care)
