# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-07-14

### Added

- Swipe between images in the lightbox: swiping left or right moves through
  the set the image was opened from (the feed or your favourites), and
  swiping near the end of the feed loads the next page of results so
  browsing continues seamlessly. Swiping is suspended while zoomed in, so
  drags pan the image instead; zoom back out (or double-tap) to resume
  paging.
- A one-time in-app review prompt: after the fifth image is saved to
  favourites, the app asks Google Play to show its rate-this-app dialog.
  The request is only ever made once, and removing favourites does not
  reset the count.

## [1.3.0] - 2026-06-28

### Added

- Share an image from the lightbox: a new **Share** action opens the Android
  share sheet so you can send the image's Nexus Mods page URL to other apps.

### Fixed

- The keyboard no longer springs back up when returning to the feed after
  closing the lightbox following a search.
- The active search term is no longer shown in the app bar while viewing the
  Favourites tab, where it does not apply.
- The lightbox action row in the favourites view no longer wraps onto two
  lines; the actions stay on a single line and scale to fit narrow screens.

## [1.2.0] - 2026-06-22

### Added

- Local favourites: save any image to an on-device gallery from the lightbox
  (tap **Save**), browse saved images in the new **Favourites** tab (newest
  first, in your choice of list, grid or planetarium layout), and remove one
  from the favourites lightbox via a confirmable **Remove from favourites**
  action. Favourites persist across app restarts.

## [1.1.4] - 2026-06-22

### Fixed

- Switching to grid view after scrolling past the first page now loads the
  next matching page immediately, instead of stalling until the next manual
  scroll.

## [1.1.3] - 2026-06-10

### Changed

- API requests now time out and retry transient failures (HTTP 429 and 5xx
  server errors) with exponential backoff, honouring a `Retry-After` header
  when present, instead of surfacing the error immediately.

## [1.1.2] - 2026-06-10

### Fixed

- The planetarium's auto-glide no longer drifts erratically for a while after
  the screen sleeps and wakes mid-glide.

## [1.1.1] - 2026-06-10

### Fixed

- Planetarium tiles no longer come back dim (with the GPU repainting
  needlessly) after switching tabs mid-fade.
- Fixed a memory leak that kept a decoded thumbnail alive for every
  planetarium tile load and aspect-ratio lookup.
- Devices without Flutter GPU support now see a clear message on the Sphere
  tab instead of a silently blank view.
- Failed tile loads now retry a few times with a cooldown instead of leaving
  permanent grey tiles in view.
- The planetarium's load region now follows the actual viewport, so screen
  corners fill correctly in landscape.
- Fixed texture-pool races that could orphan GPU textures or visibly restart
  a tile's fade-in.
- Refreshing while on the Sphere tab keeps the view mounted — no more
  skeleton flash or camera reset.

## [1.1.0] - 2026-06-08

### Added

- **Grid layout.** A compact three-column thumbnail grid for fast scanning of
  the feed. Tapping a thumbnail opens the full, uncropped image in the lightbox.
- **Planetarium (3D sphere) layout.** A third way to browse: you sit at the
  centre of a sphere whose interior is tiled with image thumbnails (a Goldberg
  polyhedron of hexagons and pentagons, so there's no pole or seam). Drag to
  look around in any direction; tiles continuously recycle and page through the
  feed as they rotate into view, and tapping a tile opens it in the lightbox.
  When left untouched it eases into a slow, wandering auto-glide that stops the
  moment you touch the screen. Built on Flutter's native 3D stack
  (flutter_scene + flutter_gpu).
- **Layout picker.** The listing layout button now cycles Feed → Grid → Sphere,
  and long-pressing it opens a menu to jump straight to a layout.

### Changed

- The lightbox now frames each image by its true aspect ratio from the first
  frame and cross-fades the full-resolution image in over the thumbnail, so the
  image sharpens in place instead of appearing to "pop in" after a reflow.

## [1.0.0] - 2026-03-24

### Added

- Initial release: a single-column, Instagram-style feed of Nexus Mods images
  with user header, avatar and time-ago, infinite scroll, a full-screen lightbox
  with pinch/double-tap zoom, and "View on Nexus Mods" links.
