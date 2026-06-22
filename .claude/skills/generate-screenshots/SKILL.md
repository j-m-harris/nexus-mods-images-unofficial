---
name: generate-screenshots
description: Generate the standard set of app screenshots by driving the running app on the Android emulator and capturing each state with adb. Use when the user wants to (re)generate the application screenshot set, refresh store/marketing screenshots, or capture the app's key screens.
---

# Generate app screenshots

Drives the **real** running app on the Android emulator and captures a fixed,
ordered set of screenshots with `adb exec-out screencap`. Driving the real app
(rather than an `integration_test` golden) is deliberate — it's the only way to
capture the Flutter GPU **planetarium/sphere** view, which doesn't render under
the test harness.

## Target & conventions

- **Device:** Android emulator, default `emulator-5554`. If a different emulator
  is connected, substitute its id (`flutter devices` / `adb devices`).
- **Reference resolution:** 1080×2400 (density 420). Tap coordinates below
  assume this. **If `adb -s <dev> shell wm size` differs, recompute** — see
  [Coordinates](#coordinates).
- **Output:** `screenshots/`, created at repo root if absent. PNG, named
  `NN-slug.png` (zero-padded order + short slug).
- **Determinism:** capture in order on a fresh launch so the feed content and
  view state are predictable. Don't reorder — later shots depend on the view
  state left by earlier ones (list → grid → sphere is a single cycling button).

## Prerequisites

1. Emulator is booted: `adb -s emulator-5554 get-state` returns `device`.
   (List/boot with `flutter emulators`.)
2. Repo dependencies resolved: `flutter pub get`.
3. No stale instance: only one app instance should drive the captures.

## Procedure

### 1. Launch the app

Launch on the emulator and leave it running in the background:

```
flutter run -d emulator-5554
```

Wait until the first feed page has **loaded** (cards/thumbnails visible, not the
loading spinner) before the first capture — the feed fetches over the network.
Poll rather than assuming a fixed delay.

### 2. Capture each screenshot

Helper for a capture:

```
adb -s emulator-5554 exec-out screencap -p > screenshots/NN-slug.png
```

Driving gestures:
- **Tap:** `adb -s emulator-5554 shell input tap X Y`
- **Long-press:** `adb -s emulator-5554 shell input swipe X Y X Y 800`
  (same start/end point, ~800 ms duration)

Work through the set **in this order**:

| #  | File | State to capture | How to get there |
|----|------|------------------|------------------|
| 01 | `01-list-view.png` | Initial startup, **detail list view** (the default layout) | Fresh launch; wait for the feed to load. Capture before touching anything. |
| 02 | `02-grid-view.png` | **Grid view** | Tap the layout button once (cycles list → grid). Wait a beat for relayout. |
| 03 | `03-planetarium-view.png` | **Planetarium / sphere view** | Tap the layout button again (grid → sphere). Wait for the 3D scene to render its tiles. |
| 04 | `04-view-menu.png` | **View menu** (list / grid / sphere options) | **Long-press** the layout button to open the view menu sheet. |
| 05 | `05-search.png` | **Search menu** | Dismiss the view menu (tap outside / back), then tap the **Search** nav button. |
| 06 | `06-game-picker.png` | **Game search filter** — the list of available games | In the search screen, tap the **game filter** control to open the game picker sheet; capture with the games list showing. |
| 07 | `07-lightbox.png` | **Lightbox** — full-screen image detail view | Return to the feed (Home nav button). Tap a **random** feed image to open the lightbox; capture with the image and its info panel showing. |
| 08 | `08-favourites-grid.png` | **Favourites view** (grid layout) with saved images | Save a few images first: from the feed grid, open a tile → tap **Save** in the lightbox → close; repeat for 3–4 images. Then tap the **Favourites** (heart) nav button. Ensure the layout is **grid** (cycle the layout button to the grid icon if needed). Capture with the saved thumbnails and the "Favourites" subheader showing. |

### 3. Finish

- Stop the app (`q` in the `flutter run` session, or quit the background run).
- Report the list of files written under `screenshots/`.

## Coordinates

The bottom nav is a single row of **5 equal-width** buttons (Home, Search,
**Favourites**, **Layout toggle**, Refresh), each occupying ⅕ of the width.
Button centres for a 1080-wide screen:

| Button | Center X |
|--------|----------|
| Home | 108 |
| Search | 324 |
| **Favourites** | **540** |
| **Layout toggle** | **756** |
| Refresh | 972 |

The nav row sits at the bottom; tap **Y ≈ 2330** for 2400-tall (≈ 97% of
height). For other sizes, derive: `X_center = width * (buttonIndex*2+1)/10`,
`Y ≈ height * 0.97` (buttonIndex 0–4).

The **game filter** control and the view/search sheets are laid out
dynamically — locate them on the captured frame (or via the visible labels)
rather than relying on fixed coordinates, since their positions depend on
content and safe-area insets.

## Notes / gotchas

- The layout button **cycles** (list → grid → sphere → list). Shots 02 and 03
  rely on starting from list (shot 01), so don't cycle out of order.
- Give the **planetarium** a moment to load its GPU tiles before capturing, or
  you may catch a partially-loaded sphere.
- If the feed is empty/errored on launch (network), retry the launch — the app
  retries transient API failures, but a capture taken mid-error will show the
  error state.
- Screenshots are full-frame device captures (include the status bar). If clean,
  status-bar-free frames are needed later, that's a separate enhancement.
