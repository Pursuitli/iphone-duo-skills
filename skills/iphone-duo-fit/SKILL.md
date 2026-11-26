---
name: iphone-duo-fit
description: Fit an existing iPhone app to the iPhone Duo (Apple's foldable, iOS 27.1) so it is right in every pose — closed on the 466×678pt outer display with the system's vertical control column on the right, open upright at 669×951pt, open on its side at 951×669pt, and across a fold or a rotation mid-task — for SwiftUI/UIKit apps and for web/Capacitor apps alike. Use this whenever the user mentions the iPhone Duo, a foldable iPhone, "folded / unfolded", the outer or inner display, the Duo simulator, Xcode 27.1, a strip or sidebar of controls beside the clock, an app that looks stretched when the phone is opened or squeezed when it is closed, buttons that do not line up with the camera, a sheet that sits 8pt inside the screen, or an audit of how an app behaves on every Duo pose. Also use it when someone asks how to make an app "work on all screen sizes" and an iPhone is in scope, because the Duo is the size that breaks the usual phone/iPad split.
---

# Fitting an app to the iPhone Duo

The iPhone Duo is one phone that is three screens. Closed, it is a narrow
phone whose right edge belongs to the system. Open and upright, it is wider
than any iPhone and reports iPad-class size classes. Open on its side, it is
wide enough for two panes. The same person crosses all three in one task, so
an app is not "fitted" until every screen is right in every pose and the
transition between poses keeps the person's place.

Everything below was paid for in a shipped mail app, measured on the Duo
simulator pixel by pixel. Where a number is given it was measured; where a
rule is given the reason is beside it. Copy the rule, change it when the reason
does not hold.

## How to work

0. **Build against the iOS 27.1 SDK.** An app built with an older SDK is
   letterboxed on the open display and never sees the column; nothing below
   applies to it. The App Store takes 27.1-built binaries once the GM ships.
1. **Read `references/device-facts.md` first.** Sizes, poses, size classes,
   the system column's metrics, and what the simulator can and cannot do.
   Do not trust your memory of the Duo — it was announced on 2026-09-09 and
   most training data predates it.
2. **Audit before you change anything.** Build the screen × pose matrix in
   `references/audit.md` for the app in front of you: every screen the app
   presents (root screens, pushed screens, sheets, covers, alerts) against
   the three poses plus the two transitions. Run `scripts/audit_code.sh` on
   the repo — it lists the decisions made from the wrong signal (size
   classes, the idiom, `UIScreen.main`, orientation, Tailwind `md:`).
3. **Fix in this order,** because each step is the foundation of the next:
   - Layout decisions come from the **measured window width**, never the
     size class, the idiom, or the orientation (below).
   - Ask **"is this a Duo?" once**, from the device, not the width.
   - The **closed pose**: the app's bar controls move into the system's
     column and align to the hardware axis. Presented screens become pages.
   - The **open pose**: the bar becomes a side bar; on its side, the split.
   - The **fold and the rotation** keep the screen's identity and state.
4. **Measure before you show anyone.** `scripts/measure_column.py` on a
   screenshot prints every column control's centre against the system's
   Wi-Fi ring. A screenshot that "looks aligned" was 8pt off twice.
5. Then read the platform recipe: `references/swiftui.md` for a native app,
   `references/web.md` for a web or Capacitor app. A product that ships both
   fixes both, with the same numbers.

## The four decisions, in one page

### 1. Layout is a width, and the width is measured

The Duo is 466pt closed, 669pt open upright, 951pt open on its side (the
669 × 951 is the logical raster; the 626 × 890 that most sites print is the
physical panel ÷ 3, and an app never sees it). iOS
reports **regular width and regular height in both orientations of the inner
display**, so `horizontalSizeClass` says "iPad" the moment the phone opens,
`userInterfaceIdiom` says "phone" in every pose, and `UIScreen.main.bounds`
reports the **outer** display (466 × 678) even when the phone is open. None
of them answers "how wide is the window I am drawing into". Only the window
does. Apple's own guidance for the Duo: avoid checking the interface
orientation for layout; the inner display ignores the app's supported
orientations.

So: one reader at the root measures the window (`GeometryReader` at the
scene root in SwiftUI, `window.innerWidth` on the web), re-measures on every
change, and hands three named layouts down the tree:

| width | layout | what it means |
|---|---|---|
| < 600 | phone | one column; the phone's bottom bar; a message opens over the list |
| 600 – 839 | tablet | the top bar arrives, the bottom bar retires; **still one column** |
| ≥ 840 | split | a list beside a reading pane; the only place a split switches on |

Why these numbers: 600 sits under the Duo open upright (669) and the iPad
mini (744) and over the Duo closed (466) and every phone upright. 840 sits
just above the widest iPad in portrait (834), so no iPad flips into a split
when held upright, and well under the Duo on its side (951, with 84 of it
the system's column, so 867 of usable width). A fourth number (1120)
is a **density**, not a layout — wider list, wider pane — and must not create
a fourth layout. Add the safe-area insets back into the measured width, or a
Duo on its side reads 40pt narrower because of its own corners.

If the app already has breakpoints, move them to these and keep the names;
the usual 768 puts the Duo open upright in the phone layout stretched to
669pt, which is the single most common Duo bug.

### 2. "Is this a Duo?" is asked once, from the device

Width cannot tell a Duo open upright (669) from an iPad mini (744) in a
narrow window, and the Duo's closed pose needs chrome no other phone needs.
So one device question sits **on top of** the width layout, never instead
of it:

- phone idiom, **and** (`UIScreen.main.bounds` is 466 × 678 in either order
  **or** the model identifier starts with `iPhone19,4`) → Duo.
- Provide a debug switch (an environment variable) that makes any simulator
  answer yes, so the chrome can be seen on a stand-in before the Duo
  simulator is available or booted.

Then the chrome is `pick(layout, isDuo)`:

| | not a Duo | Duo |
|---|---|---|
| phone layout | the bottom bar | **the strip** in the system's column (closed) |
| tablet / split | the top bar | **the side bar** on the leading edge (open) |

iPads keep whatever they had. Nothing else in the app should ever ask
"is this a Duo" — it asks which chrome it is under.

### 3. Closed: the system owns the right edge, so join it

On the outer display iOS moves its status bar, tab bars, toolbars and
navigation bars into a **vertical column on the right**, where the thumb
is, and hands the app that column as a **trailing safe-area inset of about
85pt**. The clock and glyphs sit at the top of it, the status cluster ends
about 152pt down. Apple's rule for the column: "a rearrangement, not a
reduced feature set", and controls "hold the same position relative to the
camera".

What that means for an app with its own bottom bar:

- **Every bar control moves into the column,** full size, no bottom bar. In
  Apple's order for a vertical bar: navigation (the places / tabs) first,
  then the prominent action at the foot under the thumb, groups separated
  by a gap. Four or five places fit as circles under the status cluster.
- **On the hardware axis:** every circle's centre **48pt from the trailing
  edge** (the camera's, the clock's and the Wi-Fi ring's axis — the ring is
  41pt across), each circle **44pt** (the status capsule's size), the first
  circle's top **168pt** from the top (16 under the status cluster), 10
  between circles, 14 between groups.
- **168 is the column at rest; the Dynamic Island moves it.** A Live
  Activity, a call, a timer or a recording grows the island down the
  column, and the system takes the touches under it: circles fixed at 168
  stay drawn but cannot be pressed (PDF Duo, closed and open, Nov 2026;
  other apps' columns slide down with the island). iOS 27.1 reports the
  island, the cameras and the status column as `.occlusion` reserved
  regions. Read them in the column's own `GeometryReader` on every layout
  and keep the first circle **16 under the lowest active region that
  crosses the column** (16 under the reserved rect is the gap the rest
  values already keep: 152 + 16 = 168, lens 66 + 16 = 82); a region in the
  lower half pushes the foot up the same way. Take the larger of that and
  the rest value, animate the change, and do it in the one column view
  every strip, side bar and page shares (`references/swiftui.md` §3).
- **Held on its side the closed Duo is still the strip.** 678 × 466 is
  the tablet width, but it is the outer display: the status bar hides and
  the column is the camera's, left or right depending on which way it
  turned. Pick the strip when the window's short side is under 600, and
  stand the circles beside the lens on its 48pt axis, clear of it by 16
  (`references/device-facts.md`).
- **The content keeps the whole width up to the circles.** The place
  ignores the trailing inset and stops 6pt short of the circles' near edge
  (76pt from the edge); the list's own trailing padding shrinks to match. A
  presented page's paper stops 12pt shorter than the list (88pt) — it reads
  better with air before the column.
- **Every presented screen is a full-screen page, not a sheet.** On the
  outer display a `.sheet` is a card 8pt inside the screen with a dim behind
  it, so a column drawn inside a sheet lands 8pt left and 8pt low of the
  inbox's — a translation, every circle the same, and the tell in a
  screenshot is an 8pt band of darker ground along the top and the leading
  edge. The sheet's top gap is also height the outer display has none of.
  Host the same content in `fullScreenCover` while the chrome is the strip
  and keep the sheet everywhere else.
- **A presented page's own actions stand in the column too:** Close / Back
  at the top, then the prominent action (Send), then its groups (Attach,
  Formatting; Reply all, Reply, Forward). The header keeps the title alone —
  no "Cancel" word, no verb row at the foot. Share one column frame across
  every presented screen so they cannot drift apart by a point.
- **Screens that stack their own chrome need the inset topped up.** A root
  inside a `NavigationStack` did not receive the shell's inset, and its
  controls were photographed under the camera. Top up whatever is missing to
  the content inset on that screen alone.
- **Nothing clips the column.** A zoom/transition wrapper that clips a
  presented page to the safe width cuts the column off (it is drawn in the
  reserved inset, outside that frame). Clip only while the transition is
  scaling.
- **Condense where the column is the way back:** in Settings show the one
  place that returns home; a Trash place appears only while you are in it.

### 4. Open: the bar becomes a side bar, the split runs under the column

- Upright (669): the **tablet** layout — still one column, a message opens
  over the list — with the bar's controls as **icons in a 72pt side bar on
  the leading edge** (the pill's own circles standing up, the prominent
  action at the foot) and the top bar gone. Names become accessibility
  labels. Nothing in the side bar shrinks or minimises on scroll.
- On its side (951): the **split**. The inner display on its side reserves
  the same trailing column (84pt) for its clock and bars — upright it keeps
  horizontal bars instead (top 82 / bottom 83) — so let the reading pane
  **run under it** and keep only the pane's **subject / title row clear of the
  clock** (axis 48 + ring 20.5 + 12 of air = about 80pt), with the row below
  running the whole width. A fixed-width pane (a calendar's event pane)
  keeps its measure with the column's worth of it under the column, so the
  grid beside it gains the room.
- **A pane takes the width it is offered, never the width its content
  wants.** A pane that measured its own drawn width to decide whether its
  verbs carry words grew off-screen when a Cc line outgrew it, read its own
  grown width as "wide", and locked. Read the offered width from the root
  and stack the verbs under 480pt of pane.
- A top bar built for 834pt wraps at 669: replace it on the Duo with the
  side bar drawn inside the cover, verbs as circles under the places.
- The fold on the open pose on its side is a division region about 40pt
  wide down the middle of the safe width. Interactive elements (a divider,
  a button) displace away from it; scrolling content does not. Read it from
  `reservedRegions(kind: .division)` rather than assuming the centre.

### The fold and the rotation

Closing the phone mid-letter is a **layout change on a living screen**, not
a new screen. The place keeps its structural identity across the flip (one
view tree, the chrome swapping around it), open state is held as data that
is true at every width and only *drawn* differently, so a composer beside a
list rides into the full page as the same model and the pane comes back when
the phone opens. Screens built once per branch were destroyed by the
rotation. Animate the swap on the chrome's own curve; under Reduce Motion a
fade.

## Measure, do not eyeball

- `scripts/duo-sim.sh` creates and boots your own Duo simulator (never take
  over one someone else has open), installs a build and launches it with
  debug environment variables the right way (`SIMCTL_CHILD_` prefix in the
  environment of `simctl launch`; arguments after the bundle id are silently
  ignored).
- `scripts/measure_column.py inbox.png reader.png` finds every ring and
  circle in the trailing column of a closed-Duo screenshot and prints its
  centre from the edge and its top. The system's ring reads 48; every app
  control must too, and every presented screen's first control must land on
  the inbox strip's pixels. Exit code 1 when something is off.
- A UI test that asserts the same (`references/audit.md` has the XCTest
  shape) keeps it true after you leave.
- Poses are set only in the Simulator app's Device Hub (Closed / Book /
  Open / Rotate); `simctl` has no pose command. So: screenshot the closed
  pose from the command line, ask a person for the open pose, and use the
  iPad-sized stand-in with the debug switch for the side bar until then.

## Status bar colour

On the closed Duo (and open on its side) the status bar lives in the side column, not over the top of the page. A screen that asks for white status text because a coloured header sits under the status bar on other iPhones makes the clock, Wi-Fi and battery disappear on the Duo. Wherever the column is present, return `.default` so the system picks the readable colour, dark on light and light in dark mode, and ask again after every fold or rotation. `references/swiftui.md` §8 has the fix.

## What not to do

- Do not branch on `horizontalSizeClass`, `userInterfaceIdiom`,
  `UIScreen.main`, `interfaceOrientation`, or `UIDevice.orientation` for
  layout. Each answers a different question than the one you have.
- Do not shrink the controls to fit them beside the content; the column is
  the system's room and the content gets the rest.
- Do not build a "Duo mode" with fewer features. Apple's phrase is a
  rearrangement; a person who folds the phone loses no verb.
- Do not treat iPads as Duos because the width matches; ask the device.
- Do not report "aligned" from a screenshot you did not measure.
- Do not hard-code the column's top as the final answer: it is the floor,
  and the island's occlusion region decides the rest.

## Files

- `references/device-facts.md` — sizes, size classes, the system column's
  metrics, simulator and Xcode facts, Apple's stated rules. Read first.
- `references/swiftui.md` — the native recipe: the width reader, the device
  question, the strip, the side bar, the column frame, pages not sheets,
  the traps and their tells, and §9 the column's vocabulary screen by
  screen (glyph sizes, order and gaps, busy/disabled states, the page
  header, the foot object, the strip's motion).
- `references/web.md` — React / Capacitor / CSS: breakpoints, the resize
  store, safe-area variables, DevTools device, what a webview can and cannot
  see of the poses.
- `references/audit.md` — the screen × pose matrix, the checklist, the
  XCTest axis check, how to read a screenshot.
- `scripts/audit_code.sh`, `scripts/duo-sim.sh`, `scripts/measure_column.py`.
