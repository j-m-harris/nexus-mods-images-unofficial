# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
