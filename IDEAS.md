# Feature Ideas

Candidate features for the app, grounded in what already exists. The standout
gap is that **nothing persists** — every filter, layout, and view resets on
restart, and there is no user state at all. Most of the highest-value features
fall out of adding a persistence layer.

## Tier 1 — high value, natural fit

- **Favorites / collections.** The single biggest missing piece. Tap-to-save on
  cards, the grid tile, and in the lightbox; a dedicated favorites screen.
  Requires a persistence layer (`sqflite`, or `shared_preferences` for a simple
  ID set) — which unlocks everything below.
- **Persist preferences.** Remember last layout, sort, per-page, and game filter
  across launches. Cheap win once persistence exists.
- **Search history + saved searches.** Search state (`searchText`, `gameId`,
  `sort`, active facets) is already a clean bundle — serialize it into a
  recent/saved-searches list. Low effort, high reuse of existing state.
- **Share & download.** The lightbox only links out to Nexus Mods today. Add
  `share_plus` (share the `siteUrl`/image) and save-to-gallery. Baseline
  expectations for an image browser.

## Tier 2 — depth on existing features

- **Richer filtering.** Only `category` facets are wired up today. Add the
  **adult content** toggle (the `adult` flag exists on every record but is
  unused), plus filter/sort by author (`ownerName`) and game.
- **Author view.** `ownerName`, `ownerAvatar`, and `ownerMemberId` already exist
  — tapping an author could open their image feed (mirrors the existing
  game-domain filter).
- **Date-range filtering** using `createdAt`.

## Tier 3 — polish / differentiation

- **Offline mode** — persist viewed pages so the feed survives going offline
  (the planetarium/grid already lean on caching).
- **Planetarium upgrades** — auto-tour mode, tap-a-face-to-open, share the
  current view.
- **Slideshow / ambient mode** in the lightbox.
- **Pull-to-refresh** and a jump-to-top button on long feeds.

## Suggested order

Do **persistence → favorites → persisted preferences** first. It is one
foundational dependency that unblocks three of the most-expected features, and
the search-state bundle is already in a shape that is easy to serialize.
