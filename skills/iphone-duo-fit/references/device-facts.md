# iPhone Duo: the facts to design against

Announced 2026-09-09, on sale 2026-10-23. Simulator in Xcode 27.1 beta (27A9269,
from 2026-09-18), device type `com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`,
model identifier `iPhone19,4`, runs only on the iOS 27.1 runtime (24A94401; the
27.2 beta lists it unsupported). The numbers below come from Apple's own
simulator device profile (`/Library/Developer/CoreSimulator/Profiles/DeviceTypes/iPhone Duo.simdevicetype/Contents/Resources/capabilities.plist`)
and from screenshots of that simulator at 3×; treat any number you did not
measure yourself as a claim.

## The three screens

| pose | display | **points (what your app sees)** | logical raster | physical panel | size classes (w × h) |
|---|---|---|---|---|---|
| closed | outer, 5.4" | **466 × 678** | 1398 × 2034 @3× | 1398 × 2034, 460 ppi | compact × regular |
| open, upright | inner, 7.6" | **669 × 951** | 2007 × 2853 @3× | 1878 × 2670, 430 ppi | **regular × regular** |
| open, on its side | inner | **951 × 669** | 2853 × 2007 | 2670 × 1878 | **regular × regular** |

- **The inner display is 669 × 951 pt, not 626 × 890.** 626 × 890 is the
  physical panel (1878 × 2670) divided by three, and it is what Apple's
  newsroom, Wikipedia and most device databases print. The app draws into a
  2007 × 2853 logical raster that the display downsamples (the iPhone Plus
  pattern). The simulator's device profile lists display 1 as 2007 × 2853 at
  scale 3; simulator measurements from several independent developers agree
  on 951 wide. A layout that expects 890 gets 951 and every "just under"
  threshold is off by 61pt.
- Inner aspect ≈ 1.42 (about √2).
- **The inner display reports regular size classes in both orientations**, so
  anything keyed on `horizontalSizeClass == .regular` treats an open Duo as
  an iPad, and `UITraitCollection` cannot tell the two orientations apart.
- **`UIScreen.main.bounds` reports the OUTER display (466 × 678) whether the
  phone is open or closed.** Apple says referencing the main screen "will be
  deprecated"; use `window?.windowScene?.screen` and `traitCollection.displayScale`.
  Useless for layout; excellent as a fingerprint.
- **The inner display ignores the app's supported interface orientations.**
  Apple: "avoid checking interface orientation for layout decisions; use
  size classes instead" — and for anything finer than a size class, the
  window's measured size.
- `userInterfaceIdiom` is `.phone` in every pose. `UIRequiresFullScreen` is
  still honoured for multitasking, "but your app will still resize".
- A phone build with `TARGETED_DEVICE_FAMILY = 1` runs on the Duo as a phone
  in every pose; nothing about the Duo needs the iPad family.

## Which SDK you built with decides what you get

| built against | closed | open |
|---|---|---|
| iOS 26 or earlier | the space left of the status bar and camera | a familiar phone size and aspect, letterboxed |
| iOS 27.0 SDK | extends under the status column | the whole inner display, horizontal bars |
| **iOS 27.1 SDK** | reaches the edge, **vertical bars** in the column | vertical bars on its side, horizontal bars upright |

So "rebuild with Xcode 27.1" is step zero; nothing below is available to an
app built against an older SDK, and the App Store rejects beta-built
binaries until the 27.1 GM.

## Safe areas per pose (points; measured on the 27.1 simulator by several developers, Apple's Figma kit agrees on 84)

| pose | top | leading | bottom | trailing | content inside |
|---|---|---|---|---|---|
| closed (outer) | 0 | 0 | 34 | **84** | ≈ 382 wide |
| open upright | 82 | 0 | 83 | 0 | 669 × 786 |
| open on its side | 24 | 0 | 34 | **84** | 867 × 611 |

- The trailing 84 (an app sees ≈ 85 in `safeAreaInsets.trailing`) is the
  **system's column**: on the outer display and on the inner display on its
  side, the status bar, tab bar, toolbars and navigation bar all share one
  vertical bar on the hardware edge. **The inner display upright is the one
  pose that keeps horizontal bars** (top 82 / bottom 83).
- The fold on the open pose on its side is a **division region** about
  **40pt** wide, at x ≈ 455–495 of the 867 safe width. Reserved regions come
  from `GeometryProxy.reservedRegions(kind: .division | .occlusion)` in
  SwiftUI and `UIView.reservedRegions(kind:)` in UIKit; interactive
  elements displace away from the fold while scrolling content does not.
- Safe areas are asymmetric and can flip: in right-to-left languages the
  column stays on the hardware side; in Split View each app's column is on
  its outer edge, so the left app's controls are on the left.

## What the system does in the column

Apple, Tech Talk "Design for iPhone Duo" (developer.apple.com/videos/play/tech-talks/111466)
and the HIG page "Designing for iPhone Duo":

- Symbol items stand vertically; text-only items and custom views stay
  horizontal. Back / Close at the top, then prominent actions (Done); top-bar
  items go to the top of the strip, bottom-bar items to the bottom; the tab
  bar stays bottom-aligned; items overflow from the bottom up. "Provide both
  a title and a symbol."
- "A rearrangement, not a reduced feature set." Scrolling content never
  displaces the controls.
- Controls on the vertical axis "stay aligned with the hardware — they hold
  the same position relative to the camera on the outer display".
- Sheets on the outer display get vertical bars too (opt out with
  `toolbarVerticalBehavior(.disabled)`); sheets, alerts and menus slide aside
  from the fold.
- On the inner display a `TabView` with `.sidebarAdaptable` becomes a left
  sidebar (`defaultTabBarPlacement(.sidebar)`).

Measured on the simulator, closed pose, 3× (`scripts/measure_column.py`):

| thing | value |
|---|---|
| trailing safe-area inset the app receives | ≈ **85pt** (255px) |
| the status cluster (clock, Wi-Fi ring, dots) ends | ≈ **152pt** down |
| Wi-Fi ring diameter | **41pt** |
| centre axis of the ring, the clock and the camera, from the trailing edge | **48pt** (1254px) |
| the system's own capsule size in the column | **44pt** |
| the rounded bezel the simulator paints into the screenshot | the last ≈ 8pt of the trailing edge (grey) |
| a `.sheet` on the outer display | a card **8pt** inside the screen on every side, dimmed ground behind |
| corner radii from the device profile | outer: 8 top-left / 59 top-right; inner: 55 |

Derived numbers that worked (a mail app's own column, built with the app's
bar controls rather than the system's toolbar):

| constant | value | why |
|---|---|---|
| control circle | 44 | the system's capsule |
| axis from the trailing edge | 48 | the hardware axis |
| first control's top | 168 | 16 under the status cluster |
| gap between controls / between groups | 10 / 14 | Apple keeps a space between groups from different bars |
| content inset from the trailing edge (lists, root places) | 76 | 48 + 22 + 6pt of air before the circles |
| content inset for a presented page's paper | 88 | 12 more; "the paper too wide" at 76 |
| clock clearance on the open pose on its side (what the title row keeps clear of) | ≈ 80 | 48 + 22 + 12 |
| side bar width (open pose, leading edge) | 72 | the bar's 48pt circles with 12 each side |

## The 27.1 APIs, by name (all "iOS 27.1 beta" on developer.apple.com)

Use these when the app uses the system's bars; the column recipe in this
skill is for apps whose bar is their own. SwiftUI's Duo symbols are declared
in **SwiftUICore** — a typecheck that cannot find them is usually importing
the wrong module or the wrong SDK.

- SwiftUI: `toolbarVerticalBehavior(_:)` (`.disabled`), `toolbarVerticalCompressionBehavior(_:)`,
  `@Environment(\.toolbarVerticalEdge)` (`HorizontalEdge?`), `ToolbarItem`
  `axisBehavior(.verticalPreferred / .horizontalOnly)`, `visibilityPriority`,
  `ToolbarOverflowMenu`, `.cancellationAction`, `.topBarPinnedTrailing`;
  `ArrangementView<Primary, Secondary>` + `.arrangementViewStyle(.split.axes(.horizontal) / .overlay)`,
  `splitArrangementLayoutRatio`, `overlayArrangementEdge`;
  `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)`;
  `View.onHingeChange(isEnabled:_:)` with `DeviceHinge` / `DeviceHingeContext`;
  `contentMargins(for: .container)`; `sceneAccessory`, `CameraCaptureAccessory`.
- UIKit: `UIArrangementViewController` (`setViewController(_:for:)`, `updateArrangement(_:)`),
  `UIView.reservedRegions(kind:options:)`, `UIHingeInteraction`,
  `UIViewController.preferredVerticalBarBehavior` (`UIVerticalBarBehavior`),
  `verticalBarCompressionBehavior`, `UITraitCollection.verticalBarEdge`
  (`.unspecified` where there is no bar), `UIBarButtonItem.axisBehavior` /
  `visibilityPriority`, `navigationItem.leadingItemGroups` / `trailingItemGroups`
  / `pinnedTrailingGroup` / `additionalOverflowItems`, `UIWindowScene.effectiveGeometry`
  (KVO, `windowScene(_:didUpdateEffectiveGeometry:)`).
- Rules from the talks: keep navigation outside arrangement views; do not put
  arrangement views inside a `List` or `ScrollView`; prefer even column
  counts across the fold; new windows open only on the inner display.

## Simulator and toolchain facts

- Xcode 27.1 beta: needs macOS 26.6; a 2 GB xip plus a separate iOS 27.1
  runtime (`xcodebuild -downloadPlatform iOS`, about 7.85 GB). First launch
  takes minutes. StandBy and most app extensions are unavailable on the Duo
  simulator. Build with `DEVELOPER_DIR=/path/to/Xcode-beta.app/Contents/Developer`.
  The Xcode 27.0 release has **no** Duo simulator.
- Apple ships its own agent skills with Xcode 27: `xcrun agent skills export --output-dir <dir>`
  exports seven, including `app-resizability` ("Get my app ready for the
  iPhone Duo"). Read it beside this one; it is the API catalogue, this is the
  measured fit.
- **Poses are set in the Simulator app's Device Hub** (Closed / Book / Open /
  Rotate, plus a hidden hinge-angle slider behind Option). `simctl` has no
  pose command. A fresh device boots **closed**; `simctl io screenshot` then
  gives 1398 × 2034 with the status cluster on the right edge. Two community
  tools post the hinge angle from the CLI — artemnovichkov/hinge and
  EvanBacon/serve-sim's Duo verification skill — unverified here; on a shared
  machine, prefer asking a person for the open pose to driving the UI.
- `simctl launch` takes environment variables as `SIMCTL_CHILD_<NAME>=…` in
  the environment of the command. Anything after the bundle id is an
  argument to the app; a `NAME=1` written there is silently ignored.
- `SIMULATOR_MODEL_IDENTIFIER` in the app's environment reads `iPhone19,4`;
  `SIMULATOR_MAINSCREEN_WIDTH/HEIGHT` read 1398 / 2034 even when open.
- A fresh boot may log "Data Migration Failed" in `bootstatus` and boot anyway.
- Before the Duo simulator exists on a machine, an iPad Pro 11 (iOS 27)
  simulator at a narrow window plus the app's own "pretend Duo" debug switch
  shows the side bar; any iPhone with the switch shows the strip beside the
  content (no reserved column, so the strip takes its own 64pt).
- Never take over a simulator someone else has open in Xcode: create your
  own (`scripts/duo-sim.sh`).

## Web facts (Safari / a WKWebView on iOS 27)

- **Safari cannot tell you the phone folded.** Neither CSS Viewport
  Segments (`horizontal-viewport-segments`, `env(viewport-segment-*)`) nor
  the Device Posture API is implemented (WebKit standards-positions #327 and
  #328, open since 2024 with no position). What you get is a **resize**.
- `env(safe-area-inset-*)` works with `viewport-fit=cover` and is
  **asymmetric**: right ≈ 84 CSS px on the outer display where the column
  is, left 0. Use `100dvh`, not `100vh`.
- **Known WebKit timing bug:** after closed → open, `window.innerWidth` can
  still read 466 until a later layout pass. Re-measure on the next frame
  *and* again shortly after (a second `requestAnimationFrame`, or a
  `ResizeObserver` on the root), and never cache the width.
- Chrome DevTools: add custom devices 466 × 678, 669 × 951 and 951 × 669,
  DPR 3, mobile UA. DevTools cannot show the reserved column; only the
  simulator can.
- If the fold's position matters to a web app, a native bridge is the only
  way: erkamyaman/capacitor-foldable (polyfills both web APIs and sets
  `--fold-*` variables and a `vertical-bars` class) or Capacitor's draft
  DisplayFeatures plugin.

## Sources

- developer.apple.com/iphone-duo (hub); developer.apple.com/news/?id=nyuppv9r (2026-09-18 resources)
- Tech Talks: 111461 Prepare your app, 111462 Raise the bar, 111463 Strike a pose, 111464 Multiple displays and scenes, 111465 Camera, **111466 Design for iPhone Duo** — `developer.apple.com/videos/play/tech-talks/<id>/`
- developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo
- developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo
- The simulator device profile (path above): display 0 = 1398 × 2034, display 1 = 2007 × 2853, both scale 3
- safearea.info (outer insets); blakecrosley.com/blog/iphone-duo-for-developers (669 × 951, the 1.42 problem); sarunw.com "adapting-*-for-iphone-duo" series; sven-ericmolzahn/iphone-duo-skill (simulator-measured inset table)
- WebKit standards-positions issues 327 / 328; erkamyaman/capacitor-foldable issue #5 (the innerWidth timing bug)
