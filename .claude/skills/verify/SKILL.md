---
name: verify
description: Build, launch, and drive this Flutter app on the Android emulator to verify a change end-to-end,
  including capturing animations frame-by-frame.
---

# Verify a change on the Android emulator

Companion to `generate-screenshots` (same device conventions: `emulator-5554`, 1080x2400, bottom-nav tap
coordinates). This skill adds the launch/restart and animation-capture recipe.

## Launch

```
flutter emulators --launch Medium_Phone_API_36.1   # if adb devices shows nothing
flutter run -d emulator-5554 --pid-file <scratch>/flutter.pid > <scratch>/flutter-run.log 2>&1   # background
```

Boot is ready when `adb -s emulator-5554 shell getprop sys.boot_completed` prints 1 (~3 min cold).
App is ready when the log contains "A Dart VM Service" (~4 min first build). Then wait a few seconds for the
feed to load over the network before driving.

## Compare fixed vs unfixed without rebuilding

`--pid-file` enables signal-driven reloads, so you can flip the working tree and hot-restart in seconds:

```
git stash              # or checkout the pre-change state
kill -USR2 $(cat <scratch>/flutter.pid)     # hot restart (~3 s); SIGUSR1 = hot reload
# drive + capture, then: git stash pop && kill -USR2 ... again
```

Hot restart resets app state: the feed refetches (content may have changed — re-screenshot before computing
tap coordinates) and scroll position resets.

## Capture an animation (e.g. Hero flights, transitions)

Single screencaps are too slow for 200-300 ms transitions. Record and extract frames instead:

```
adb -s emulator-5554 shell screenrecord --time-limit 8 --bit-rate 8000000 /sdcard/rec.mp4 &
sleep 1.5; <drive taps>; wait
adb -s emulator-5554 pull /sdcard/rec.mp4 <scratch>/rec.mp4
ffmpeg -y -i <scratch>/rec.mp4 -vsync 0 -frame_pts true <scratch>/frames/f%04d.png
```

screenrecord only emits frames while pixels change, so frames cluster at the transitions — a gap in the
frame numbers separates the open animation from the close animation. Effective rate ~15 fps, giving 3-5
frames per 220 ms transition; read the mid-transition frames. Clean up `/sdcard/rec*.mp4` afterwards.

## Gotchas

- Feed sorts by newest and new images arrive constantly: never reuse tap coordinates across a restart
  without re-screenshotting.
- The first feed card is often adult-veiled: a tap reveals instead of opening the lightbox. Prefer a
  non-veiled card as the tap target (or tap twice).
- In the lightbox, tapping the image area closes it; swipe (`input swipe 850 900 150 900 120`) pages to the
  next image.
- Quit with `kill $(cat <scratch>/flutter.pid)` — the background `flutter run` has no stdin for `q`.
