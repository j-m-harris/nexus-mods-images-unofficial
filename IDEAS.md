# Feature Ideas

Candidate features, grounded in what exists as of **v1.3.0**. The previous revision of this file predates
favourites and sharing; both have since shipped, so the list below is a fresh pass. It is ordered by how strongly
users of other Android image apps (gallery apps, Reddit/Pinterest-style browsers, wallpaper apps) expect each
feature, weighted by how cheaply the current code supports it.

Shipped since the last revision: local favourites with their own tab and layouts (1.2.0), share from the lightbox
(1.3.0), a persistence layer (`shared_preferences` via `FavouritesService`), the one-time in-app review request
(fires on the fifth favourite save), lightbox swiping (1.4.0), and the adult-content gate (a three-way setting
in a new settings sheet off the app bar: Hide excludes adult images from the feed server-side, Blur — the
default — shows them behind a blurred tap-to-reveal veil, Show renders them normally with just the badge.
Sphere tiles bake the blur into their textures; tapping one opens the still-veiled lightbox. Reveals are
session-scoped and shared across surfaces, so unblurring a card carries into its lightbox page). Pull-to-refresh
also already exists on the feed.

Code-quality and performance follow-ups live in `RECOMMENDATIONS.md` and `PERFORMANCE_NOTES.md`; this file is
product features only.

## Tier 1 — table stakes for an image viewer

Things users will reach for instinctively because every comparable Android app has them.

- **Download to device.** Share currently sends the page URL only. Add a Download action that saves the
  full-resolution file to `Pictures/Nexus Mods` via MediaStore (no storage permission needed on API 29+), with a
  snackbar linking to the saved copy. While there, offer "share image" (the actual file via `share_plus`) next to
  the existing "share link".
- **Persist preferences.** Layout, sort, per-page and last tab still reset every launch even though
  `shared_preferences` is already a dependency. Cheap win: serialize `_layout`, `_sort` and `_perPage` the same
  way favourites are stored, restore in `initState`.
- **Settings screen.** A minimal settings sheet now exists off the app bar (it hosts the adult-content toggle).
  Grow it into the home for default layout/sort, cache controls (show usage, clear), and future options below.

## Tier 2 — discovery and depth

More ways to find and understand images, mostly built from fields the API already returns.

- **Search history and saved searches.** Search state (`searchText`, `gameId`, `sort`, facets) is a clean bundle;
  store the last N submitted searches and let users pin favourites. Surface recents under the search field, the
  way every search-driven app does.
- **Author view.** `ownerName`, `ownerAvatar` and `ownerMemberId` are already on every record. Tapping an author
  should open their image feed (the API filter mirrors the existing game filter). Pairs naturally with the next
  item.
- **Followed games.** Users typically care about two or three games, not all of Nexus. Let them follow games and
  add a "Following" feed scope (union of followed game filters, or a filter chip row). This is the foundation for
  any future "new images from your games" notification.
- **Image details sheet.** The lightbox shows a compact action row; add a swipe-up or info-button sheet with the
  full metadata already fetched: title, description, category, game, author, upload date, views, rating, plus a
  copy-link action. Comparable apps (Reddit clients, Pinterest) all offer an info surface.
- **Date-range filter** using `createdAt`, e.g. quick chips for today / this week / this month.

## Tier 3 — Android-native differentiation

Features that make it feel like a first-class Android app rather than a web view. These are where a modded-games
art feed can genuinely stand out.

- **Set as wallpaper.** The obvious killer feature for this content: game screenshots and artwork are exactly
  what people hunt wallpaper apps for. A lightbox action calling `WallpaperManager` (home/lock/both) via a small
  platform channel or `wallpaper_manager_plus`.
- **Daily wallpaper rotation.** Once set-as-wallpaper exists: a WorkManager job that rotates the wallpaper from
  favourites or a saved search each day. This is the retention hook of apps like Backdrops and Muzei; a Muzei
  provider would be a cheap additional integration for that audience.
- **Home screen widget.** A glanceable "image of the day" (or random favourite) widget that opens the lightbox
  on tap.
- **Planetarium as screensaver.** The sphere is the app's signature feature; exposing it as an Android Daydream
  (screensaver) service would be unique, and the auto-glide behaviour already exists.
- **App shortcuts.** Long-press launcher shortcuts for Search, Favourites and Random feed — trivial manifest
  work.
- **Deep links.** Register for `nexusmods.com` image URLs so links shared from elsewhere open in the app's
  lightbox instead of the browser.

## Tier 4 — polish and resilience

- **Offline-safe favourites.** Favourites persist metadata only; the pixels live in the normal image cache and
  can be evicted, so the favourites tab can go blank offline. Copy each favourited thumbnail (or full image) into
  app storage on save, and delete it on remove. This makes favourites the app's reliable offline surface.
- **Collections within favourites.** Once favourites grow, users expect albums ("Skyrim builds", "wallpaper
  candidates"). A `collectionIds` field on the stored record plus a picker keeps this simple.
- **Slideshow / ambient mode** in the lightbox, feeding off the same list as lightbox swiping.
- **Accessibility pass.** There is currently not a single `Semantics`, `semanticLabel` or `Tooltip` in `lib/`.
  Nav buttons, cards, facet chips and lightbox actions need labels for TalkBack; images should use their title as
  `semanticLabel`.
- **Adaptive layout.** Grid column count and feed width are tuned for portrait phones; derive columns from
  available width for tablets, landscape and foldables. Also worth adopting predictive back now that the
  lightbox and search are push routes.
- **Data saver mode.** A setting to stay on thumbnails (skip the full-res upgrade and lightbox original) on
  metered connections; the card already has the thumbnail/full split, so this is mostly a gate.
- **Jump-to-top button** on long feeds (pull-to-refresh exists; a quick way back up after deep scrolling does
  not).

## Suggested order

1. Download + share-image, and preference persistence — small, independent, high-visibility wins.
2. Set-as-wallpaper, then daily rotation — the differentiating pair; the settings sheet gives rotation options a
   home.
3. Search history, author view and followed games — the discovery cluster, in whichever order feedback favours.
