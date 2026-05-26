# Nexus Mods Images (Unofficial)

A Flutter mobile app for browsing the public image feed on [Nexus Mods](https://www.nexusmods.com/) — screenshots and artwork uploaded by the community across thousands of modded games.

> **Unofficial.** Not affiliated with or endorsed by Nexus Mods. Uses the public Nexus Mods GraphQL API.

## Features

- **Infinite-scroll feed** of the latest community images.
- **Sort** by Newest, Oldest, Most Viewed, Top Rated, or Random (random seed stays stable across paginated requests so you don't see duplicates).
- **Search** by free text and **filter by game** (game list pulled from the public games dataset and ranked by downloads).
- **Category facet** filters that update with the current result set.
- **Lightbox** with thumbnail → full-resolution crossfade and tap-through to the original Nexus Mods page.
- **Adult-content flag** surfaced from the API (no separate gate is implemented client-side).

## Stack

- Flutter (Dart SDK `^3.11.3`)
- Targets Android and iOS
- HTTP via `http` + GraphQL queries hand-rolled against `api.nexusmods.com/v2/graphql`
- Image loading via `cached_network_image`; viewport-aware precache via `visibility_detector`
- Icons from `phosphor_flutter`

## Project layout

```
lib/
  main.dart                 App entry; sets a 50 MB / 80-entry image-cache cap
  theme.dart                Colors and Material theme
  models/nexus_image.dart   API DTOs (NexusImage, NexusGame, FacetItem, …)
  services/
    nexus_api.dart          GraphQL search + games-list fetch
    image_aspect_cache.dart Shared aspect-ratio cache (card + lightbox)
  screens/
    home_screen.dart        Feed, sort menu, bottom nav, pagination
    search_screen.dart      Text + game search UI
  widgets/
    image_card.dart         Grid card
    lightbox.dart           Full-screen viewer
    facets_bar.dart         Category facet chips
    skeleton_card.dart      Loading placeholder
```

Release artifacts land under `build/app/outputs/bundle/release/`, which the repo symlinks as `release/`.

## Running

```bash
flutter pub get
flutter run            # default device
flutter run -d <id>    # pick a device from `flutter devices`
```

Build a signed Android release bundle:

```bash
flutter build appbundle --release
```

(iOS builds require an Apple developer account and matching signing configuration — none is committed.)

## Notes

- `PERFORMANCE_NOTES.md` tracks a ranked list of follow-up perf work (some already applied, some pending).
- The Android `applicationId` is `com.entwiningsplines.nexusmods.images`.

## License

No license has been added. All rights reserved by default. Nexus Mods name and images shown by the app remain the property of their respective owners.
