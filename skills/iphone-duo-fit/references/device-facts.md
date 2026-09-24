# iPhone Duo: the facts to design against

Announced 2026-09-09, on sale 2026-10-23. Simulator in Xcode 27.1 beta (from
2026-09-18), device type `com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`,
model identifier `iPhone19,4`, runtime iOS 27.1. Everything measured below
was measured on that simulator at 3× scale; treat a number you did not measure
yourself as a claim.

## The three screens

| pose | display | points | pixels | size classes (w × h) |
|---|---|---|---|---|
| closed | outer, 5.4" | **466 × 678** | 1398 × 2034 (460 ppi) | compact × regular |
| open, upright | inner, 7.6" | **626 × 890** | 1878 × 2670 (430 ppi) | **regular × regular** |
| open, on its side | inner | **890 × 626** | 2670 × 1878 | **regular × regular** |

- Inner aspect ≈ 1.42 (about √2). Most sources agree on 626 × 890; one blog
  says 669 × 951 — use 626.
- **The inner display reports regular size classes in both orientations**, so
  anything keyed on `horizontalSizeClass == .regular` treats an open Duo as
  an iPad, and `UITraitCollection` cannot tell the two orientations apart.
- **`UIScreen.main.bounds` reports the OUTER display (466 × 678) whether the
  phone is open or closed.** Useless for layout; excellent as a fingerprint.
- **The inner display ignores the app's supported interface orientations.**
  Apple: "avoid checking interface orientation for layout decisions; use
  size classes instead" — and for anything finer than a size class, the
  window's measured size.
- `userInterfaceIdiom` is `.phone` in every pose.
- A phone build with `TARGETED_DEVICE_FAMILY = 1` runs on the Duo as a phone
  in every pose; nothing about the Duo needs the iPad family. Listing
  landscape orientations in `Info.plist` matters for the outer display and
  for what the app is told; the inner display does its own thing.

## What the system does on the outer display

Apple, Tech Talk "Design for iPhone Duo" (developer.apple.com/videos/play/tech-talks/111461)
and the HIG page on the Duo:

- The **status bar, tab bar, toolbars and navigation bar move to a vertical
  strip on the right**, next to the thumb. Symbol items stand vertically;
  text items stay horizontal. Back / Close at the top, Done-type actions
  under.
- On the inner display a `TabView` with `.sidebarAdaptable` becomes a **left
  sidebar**.
- "A rearrangement, not a reduced feature set." Scrolling content never
  displaces the controls.
- Controls on the vertical axis "stay aligned with the hardware — they hold
  the same position relative to the camera on the outer display".

Measured on the simulator, closed pose, 3×:

| thing | value |
|---|---|
| trailing safe-area inset the app receives (the reserved column) | ≈ **85pt** (255px) |
| the status cluster (clock, Wi-Fi ring, dots) ends | ≈ **152pt** down |
| Wi-Fi ring diameter | **41pt** |
| centre axis of the ring, the clock and the camera, from the trailing edge | **48pt** (1254px) |
| the system's own capsule size in the column | **44pt** |
| the rounded bezel the simulator paints into the screenshot | the last ≈ 8pt of the trailing edge (grey) |
| a `.sheet` on the outer display | a card **8pt** inside the screen on every side, dimmed ground behind |

Derived numbers that worked (a mail app's column):

| constant | value | why |
|---|---|---|
| control circle | 44 | the system's capsule |
| axis from the trailing edge | 48 | the hardware axis |
| first control's top | 168 | 16 under the status cluster |
| gap between controls / between groups | 10 / 14 | Apple keeps a space between groups from different bars |
| content inset from the trailing edge (lists, root places) | 76 | 48 + 22 + 6pt of air before the circles |
| content inset for a presented page's paper | 88 | 12 more; "the paper too wide" at 76 |
| clock clearance on the OPEN pose (what the title row keeps clear of) | ≈ 80 | 48 + 22 + 12 |
| side bar width (open pose, leading edge) | 72 | the bar's 48pt circles with 12 each side |

## Simulator and toolchain facts

- Xcode 27.1 beta: needs macOS 26.6; a 2 GB xip plus a separate iOS 27.1
  runtime (`xcodebuild -downloadPlatform iOS`, about 7.85 GB). First launch
  takes minutes. StandBy and most app extensions are unavailable on the
  Duo simulator. Build with `DEVELOPER_DIR=/path/to/Xcode-beta.app/Contents/Developer`.
- The Xcode 27.0 release (App Store submittable) has **no** Duo simulator.
- **Poses are set only in the Simulator app's Device Hub** (Closed / Book /
  Open / Rotate). `simctl` has no pose command. A fresh device boots
  **closed**; `simctl io screenshot` then gives 1398 × 2034 with the status
  cluster on the right edge.
- `simctl launch` takes environment variables as `SIMCTL_CHILD_<NAME>=…` in
  the environment of the command. Anything after the bundle id is an
  argument to the app; an `NAME=1` written there is silently ignored.
- `SIMULATOR_MODEL_IDENTIFIER` in the app's environment reads `iPhone19,4`.
- A fresh boot may log "Data Migration Failed" in `bootstatus` and boot anyway.
- Before the Duo simulator exists on a machine, an iPad Pro 11 (iOS 27)
  simulator at a narrow window plus the app's own "pretend Duo" debug switch
  shows the side bar; any iPhone with the switch shows the strip beside the
  content (no reserved column, so the strip takes its own 64pt).
- Never take over a simulator someone else has open in Xcode: create your
  own (`scripts/duo-sim.sh`).

## Web facts (Safari / a Capacitor webview)

- Chrome DevTools: add a custom device, 466 × 678 and 626 × 890, DPR 3,
  mobile user agent. It cannot show the reserved column; test that on the
  simulator.
- In a Capacitor webview on the closed Duo the reserved column arrives as
  `env(safe-area-inset-right)` (the trailing inset the native container
  passes through). Read it as a CSS variable once and pay it where content
  meets the edge; do not assume it is zero on a phone.
- The layout store must re-measure on `resize`, `orientationchange` and
  `pageshow`, not only on media-query changes: an installed-app container on
  a foldable can resize its window without reliably delivering the
  media-query change, and the phone chrome stays up across the inner screen.

## Sources

- apple.com/newsroom/2026/09/apple-unveils-iphone-duo (sizes)
- developer.apple.com/videos/play/tech-talks/111461 "Design for iPhone Duo"
- developer.apple.com/news/?id=k1mtkt1k (developer resources, 2026-09-09)
- blakecrosley.com/blog/designing-for-iphone-duo, sarunw.com/posts/adapting-content-for-iphone-duo
- en.wikipedia.org/wiki/IPhone_Duo; webmobilefirst.com (folded / unfolded pages)
