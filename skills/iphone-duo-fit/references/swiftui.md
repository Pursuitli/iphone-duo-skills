# The SwiftUI recipe

Code below is the shape that shipped, with the app's names replaced by
generic ones. Adapt the names, keep the structure.

## 1. One width reader at the root

```swift
enum WindowLayout: Equatable {
    case phone, tablet, split
    static let bar: CGFloat = 600      // top bar arrives, bottom bar retires
    static let splitAt: CGFloat = 840  // the only place a split switches on
    static let roomy: CGFloat = 1120   // a density, not a layout
    static func measure(_ width: CGFloat) -> WindowLayout {
        if width >= splitAt { return .split }
        if width >= bar { return .tablet }
        return .phone
    }
    var isPhone: Bool { self == .phone }
}

struct LayoutReader<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        GeometryReader { g in
            // Add the side insets back: the web's innerWidth is the whole
            // viewport, and a Duo on its side must not read 40pt narrower
            // because of its own corners. The children keep the safe area.
            let width = g.size.width + g.safeAreaInsets.leading + g.safeAreaInsets.trailing
            let layout = WindowLayout.measure(width)
            content()
                .environment(\.layout, layout)
                .environment(\.chrome, Chrome.pick(layout))
                .environment(\.roomy, width >= WindowLayout.roomy)
                .environment(\.windowWidth, width)
                .frame(width: g.size.width, height: g.size.height)
        }
    }
}
```

Mount it once, at the scene root, around the shell. Every screen reads
`\.layout` and `\.chrome` from the environment and never measures the device.

## 2. The device question, once

```swift
@MainActor enum Duo {
    static let device: Bool = {
        #if DEBUG
        if ProcessInfo.processInfo.environment["DEV_DUO"] != nil { return true }
        #endif
        guard UIDevice.current.userInterfaceIdiom == .phone else { return false }
        if model.hasPrefix("iPhone19,4") { return true }
        // UIScreen.main reports the OUTER display open or closed — the fingerprint.
        let b = UIScreen.main.bounds.size
        let w = min(b.width, b.height), h = max(b.width, b.height)
        return abs(w - 466) < 2 && abs(h - 678) < 2
    }()
    private static var model: String {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return sim }
        var s = utsname(); uname(&s)
        return withUnsafePointer(to: &s.machine) { $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) } }
    }
}

enum Chrome: Equatable {
    case bar    // the phone's bottom bar
    case top    // the wide top bar (iPads, desktop-class windows)
    case side   // Duo open: the bar's controls as a column on the leading edge
    case strip  // Duo closed: the same controls in the system's column on the right
    @MainActor static func pick(_ layout: WindowLayout) -> Chrome {
        if Duo.device { return layout.isPhone ? .strip : .side }
        return layout.isPhone ? .bar : .top
    }
}
```

`Chrome` rides the environment. Screens switch on `chrome`, never on
`Duo.device` — the device answer exists only to choose the chrome.

## 3. The shell: the strip lives IN the reserved column

The closed Duo hands the app a trailing safe inset of about 85pt. Read it in
the shell; if it is there, the strip is laid over it and the place keeps the
whole safe width. If it is not (a stand-in simulator), the strip takes 64pt
beside the place.

```swift
GeometryReader { g in
    let column = g.safeAreaInsets.trailing
    let stripInColumn = chrome == .strip && column >= DuoStrip.width
    ZStack(alignment: .bottom) {
        HStack(spacing: 0) {
            if chrome == .side { DuoSideBar(onAct: act).transition(.move(edge: .leading).combined(with: .opacity)) }
            VStack(spacing: 0) {
                if chrome == .top { topBar }
                place.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // The place runs to the foot and up to the circles: as SAFE AREA,
            // not padding, so a screen that wants to run under the column
            // (a cover image) can ignore it.
            .safeAreaPadding(.trailing, stripInColumn ? DuoStrip.contentInset : 0)
            .ignoresSafeArea(.container, edges: chrome == .strip ? (stripInColumn ? [.bottom, .trailing] : .bottom) : [])
            // The OPEN Duo's column, for a split's pane to run under.
            .environment(\.duoColumn, chrome == .side ? column : 0)
            if chrome == .strip, !stripInColumn { DuoStrip(onAct: act, top: 12).frame(width: DuoStrip.width) }
        }
        .overlay(alignment: .trailing) {
            if stripInColumn {
                // Flush with the place's trailing edge, moved out by the
                // column's width: exactly the reserved column. A trailing pad
                // inside the column's frame centres the circles on the axis.
                DuoStrip(onAct: act, top: DuoStrip.underStatus)
                    .padding(.trailing, max(0, 2 * DuoStrip.axisFromEdge - column))
                    .frame(width: column)
                    .offset(x: column)
            }
        }
        if chrome == .bar { phoneBar }
    }
    .animation(reduced ? .easeOut(duration: 0.2) : .timingCurve(0.32, 0.72, 0, 1, duration: 0.4), value: chrome)
}
```

The strip's constants:

```swift
struct DuoStrip: View {
    static let width: CGFloat = 64          // beside the place, when there is no reserved column
    static let underStatus: CGFloat = 168   // first circle's top: 16 under the status cluster
    static let control: CGFloat = 44        // the system's capsule size
    static let axisFromEdge: CGFloat = 48   // the camera's, the clock's, the ring's axis
    static let contentInset: CGFloat = axisFromEdge + control / 2 + 6   // 76: the list stops here
    static let pageInset: CGFloat = contentInset + 12                   // 88: a presented page's paper
    static let clockClearance: CGFloat = axisFromEdge + control / 2 + 12 // open pose: the title keeps clear
    // Body: a VStack of 44pt glass circles, spacing 10 (14 between groups),
    // padded .top by `top`; the prominent action at the foot with
    // Spacer(minLength: 16) above it and .padding(.bottom, 24).
    // Wrap in GlassEffectContainer(spacing: 4) on iOS 26 so the circles share
    // one material (at more spacing they melt together).
}
```

### The column follows the island

The tops above (168 under the status cluster, 82 clear of the lens, 16 in
the side bar) are the column **at rest**. A Live Activity, call, timer or
recording grows the Dynamic Island down the column and the system takes the
touches there, so circles left at 168 are drawn but dead. Read the
occlusion regions in the column view itself, every layout, and take the
larger of the rest value and 16 under the lowest region crossing the
column. Put this in the ONE column view that the strip, the side bar and
every presented page share, so they all move together (shipped in PDF Duo,
26 Nov 2026):

```swift
struct DuoColumn: View {
    // items, foot, size, top (nil = the reserved column's own rest value)…
    var body: some View {
        GeometryReader { g in
            let clear = Occlusion.clearance(g)
            DuoGlass {
                VStack(spacing: 0) { /* circles, Spacer(minLength: 16), foot */ }
                    .padding(.top, max(top ?? spot?.top ?? DuoStrip.underStatus, clear.top))
                    .padding(.bottom, max(top == nil ? spot?.bottom ?? 24 : 24, clear.bottom))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.smooth(duration: 0.3), value: clear)
        }
    }
}

struct Occlusion: Equatable {
    var top: CGFloat = 0, bottom: CGFloat = 0
    static let gap: CGFloat = 16   // the rest values keep it: 152 + 16 = 168, 66 + 16 = 82

    static func clearance(_ g: GeometryProxy) -> Occlusion {
        var c = Occlusion()
        guard #available(iOS 27.1, *) else { return c }
        let h = g.size.height, w = g.size.width
        for r in g.reservedRegions(kind: .occlusion) where r.isActive {
            let m = r.margins   // the frame includes them; keep our own 16 from the rect
            let rect = CGRect(x: r.frame.minX + m.leading, y: r.frame.minY + m.top,
                              width: r.frame.width - m.leading - m.trailing,
                              height: r.frame.height - m.top - m.bottom)
            guard rect.maxX > 0, rect.minX < w, rect.maxY > 0, rect.minY < h else { continue }
            if rect.midY < h / 2 { c.top = max(c.top, rect.maxY + gap) }
            else { c.bottom = max(c.bottom, h - rect.minY + gap) }
        }
        return c
    }
}
```

- Frames are in the reader's own coordinate space, so the region and the
  column's padding share one origin wherever the column sits (closed strip
  over the trailing inset, the side bar under the 82pt top inset, a book
  pane's floating column).
- Regions arrive a few passes after launch and change while the app runs;
  a `GeometryReader` re-evaluates when they do. Never cache them in `@State`.
- The binary must be stamped with the 27.1 SDK or every query is empty
  (`otool -l <App>.debug.dylib | grep -A4 LC_BUILD_VERSION`).
- A system notification banner is not an occlusion region; it covers every
  app for its few seconds and nothing should move for it.

Apple's order in the column, top to bottom: navigation (places / Back /
Close), then the prominent action, then groups with a 14pt gap. The
prominent *creation* action (compose, new) sits at the foot under the thumb.

Condense where the column is the way back: while Settings is up show only
the circle that returns home; a place you can only reach by a swipe or a
deep link (Trash) joins the column only while you are in it.

## 4. The side bar (open pose)

72pt on the leading edge, icons only, the names as accessibility labels, the
bar's 48pt circles unchanged (nothing shrinks on the Duo), the prominent
action at the foot. Decide per app whether secondary switches (a view
toggle) belong there; a mail app dropped its List | Feed switch from the side
bar on the founder's call and kept it in the closed strip. The top bar does
not draw when the chrome is `.side`. Nothing minimises on scroll; the
minimiser returns at once unless the chrome is the phone's bar.

A presented screen on the open pose (a full-page reader) draws the side bar
*inside* its cover, with its own verbs as extra circles under the places, so
the places remain reachable and a place chosen there closes the screen.

## 5. Presented screens: pages, with a shared column frame

```swift
/// Wraps a presented screen on the closed Duo: its content stops at the page
/// inset, and `column` stands in the reserved room on the camera's axis.
struct DuoColumnFrame<Column: View>: ViewModifier {
    let on: Bool
    @ViewBuilder let column: () -> Column
    func body(content: Content) -> some View {
        if on {
            GeometryReader { g in
                if g.safeAreaInsets.trailing >= DuoStrip.width {
                    // The stack ignores the trailing inset, so its trailing edge is
                    // the SCREEN's; a column twice the axis wide, flush to it,
                    // centres on the axis by construction (no offset arithmetic —
                    // that drifted 2pt between two screens).
                    ZStack(alignment: .trailing) {
                        content.padding(.trailing, DuoStrip.pageInset).frame(maxWidth: .infinity, maxHeight: .infinity)
                        column().frame(width: 2 * DuoStrip.axisFromEdge)
                    }
                    .ignoresSafeArea(.container, edges: .trailing)
                } else {
                    content.overlay(alignment: .trailing) { column().frame(width: DuoStrip.width) }
                }
            }
        } else { content }
    }
}
```

The column's first circle is padded `.top` by `DuoStrip.underStatus` so it
lands on the inbox strip's pixels.

**Host as a page while the chrome is the strip, a sheet otherwise:**

```swift
.sheet(item: chrome == .strip ? .constant(nil) : $reading) { readerContent($0) }
.fullScreenCover(item: chrome == .strip ? $reading : .constant(nil)) { readerContent($0) }
```

Both hosts call the same content function so they cannot drift. Apply the
same pair to every host: the composer, the invite form, the reader, reply /
forward from inside a letter, an item opened from a details card, an editor
opened from an item. Missing one shows up as that screen's column 8pt off.

The header of a presented page keeps the title (and a status word like
"Draft saved") alone; Cancel / Close / Send / Attach live in the column. A
foot object (a quick-reply field, a voice bar) comes in only when a column
circle asks for it and leaves when idle.

## 6. The split runs under the open Duo's column

```swift
// In the split container:
pane().padding(.trailing, 24 - underColumn)   // underColumn = \.duoColumn, ~85 on the Duo, 0 elsewhere
// In the pane: only the title row keeps clear of the clock.
titleRow.padding(.trailing, max(0, clearTrailing - gutter))  // clearTrailing = DuoStrip.clockClearance on the Duo
```

A fixed-measure pane (`.pane(w)` — a form beside a grid) keeps its width with
the column's worth under the column, so the grid gains the room. Only the
letter runs under; a composer beside the list and the idle line do not.

The pane takes the width it is offered:

```swift
GeometryReader { g in
    content.frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
    // decide the verbs' words from g.size.width (stack them under 480), never
    // from a measurement of the drawn header — a wide header grows the sheet
    // off-screen and then reads its own grown width as "wide".
}
```

## 7. Screens that stack their own chrome

A settings root inside a `NavigationStack` did not receive the shell's
trailing safe inset, and its top-right pill was photographed under the
camera. Top up on that screen alone:

```swift
GeometryReader { g in
    let missing = chrome == .strip ? max(0, DuoStrip.contentInset - g.safeAreaInsets.trailing) : 0
    stack.safeAreaPadding(.trailing, missing)
}
```

A cover picture that should run under the column ignores `.trailing` and is
drawn `g.size.width + g.safeAreaInsets.trailing` wide.

## 8. Traps and their tells

| tell in a screenshot | cause | fix |
|---|---|---|
| every column circle 8pt left and 8pt low of the inbox's; 8pt band of dark ground along the top and leading edge | the screen is hosted in `.sheet` | `fullScreenCover` while the chrome is the strip |
| the letter stops short of the column and there are **no** circles | a zoom / transition wrapper clips the page to the safe width; the column is drawn outside it | clip only while scaling (`clipShape(Rectangle().inset(by: on ? 0 : -10_000))` so the view keeps its identity) |
| the top circles **look fine but cannot be pressed** while a call, timer or Live Activity is running; at rest they work | the column's first circle is a constant (168, or 16 in the side bar) and the expanded Dynamic Island now lies over it, taking the touches | read `reservedRegions(kind: .occlusion)` in the column view and keep the first circle 16 under the lowest active region crossing it (§3 "The column follows the island") |
| a screen's controls sit under the camera | a `NavigationStack` root did not get the shell's inset | top up to `contentInset` on that screen |
| two presented screens' columns differ by 2pt | each did its own offset arithmetic | one shared `DuoColumnFrame` |
| the phone chrome stretched across the open display | a 768 breakpoint | 600 |
| an iPad shows the Duo's strip | Duo detected by width | ask the device |
| the pane "sometimes overflows" | it measured its drawn width to choose its words | read the offered width at its root |
| the top bar wraps its words at 669 | a bar designed for 834 | the side bar on the Duo |
| open state lost on a fold | a screen built once per layout branch | one place with structural identity; open state as data |
| the bar minimises on the Duo | the minimiser runs under every chrome | return unless chrome == .bar |
| "Executed 0 tests" | Swift Testing target | read the `.xcresult` summary |
| **the clock, Wi-Fi and battery vanish** on the closed Duo (and open on its side) | the screen asks for `.lightContent` (white status text) because a coloured hero sits under the status bar on a normal iPhone; on the Duo the status bar moves into the side column, which the hero does not reach, so white text lands on the page's own white ground | answer the status-bar style per pose: when the window has a trailing inset (> 40pt, the column) on a Duo, return `.default` instead of `.lightContent`, so the system picks dark text on a light ground and light text on a dark ground (dark mode); re-ask on every window-size change (`setNeedsStatusBarAppearanceUpdate`). Do not try to paint the hero under the column instead: the glyphs vanish again as soon as the hero scrolls away. Seen on a real Duo, OmuType 2026-10-23 |
| a page's title pushed off the top on the closed Duo | a fixed-size illustration (a 300 × 380 settings mock) plus title, steps and a button need ~720pt; the outer screen is 678 | scale the illustration on short windows (`windowSize.height < 760` → 72%), which also fixes the iPhone SE; never let a fixed drawing set the page's height |

## 9. The column's vocabulary, screen by screen (what shipped, to the point)

Everything in §3–§5 says where the column is. This says what stands in it,
because the founder of the app that paid for these numbers checked every
one on a screenshot, and the rules below are what survived.

### Circles and glyphs

| circle | glyph size | which glyphs |
|---|---|---|
| 44 (closed strip, every presented page's column) | **19** for a place icon, **18** for Back / Send / ⋯, **17** for the reply family, **16** for keyboard / forward, **15** for Close | the app's own icon set where it has one; SF Symbols at `.medium` weight otherwise |
| 48 (open side bar) | **21** for a place icon, 17–19 for the rest | same |

- **One stroke family in the column.** The Close circle first drew SF
  `xmark` at 16 semibold beside circles whose glyphs were the app's thin
  drawn icons, and it read as "too thick". It became the app's own close
  glyph at 15, the same stroke as the back arrow. Whatever set you use, use
  it for every circle; a mixed column looks like two apps.
- **Verbs of one family share one drawing.** Reply all is the reply arrow
  with a second head, built from the reply file, so stroke and curve are
  identical; two straight arrows beside a U-turn arrow read as unrelated.
  Keep one source file per glyph and let every surface (web, phone foot,
  pane, column) take it from there.
- The current place is the accent colour, every other glyph is ink; the
  place carries `.isSelected` for VoiceOver. The prominent action (Send,
  Compose, the microphone) is a filled accent circle with a white glyph.
- Every circle: `.buttonStyle(PressScale())` (the press answers under the
  finger), a `GlassID` in one shared namespace so circles morph rather than
  cross-fade, `.contentShape(Circle())`, an `accessibilityLabel` with the
  full name (the column has no words).
- A circle that opens a menu is a `Menu` whose label is the same 44pt
  frame with the same `GlassID`; a destructive item asks through a
  `confirmationDialog` anchored to it. A circle that is busy shows a
  `ProgressView` in place of its glyph (⋯ while exporting, Send while
  sending); a circle that is unavailable is `.disabled` at 0.4 opacity, not
  removed, so the column never re-flows while you look at it.

### The order, top to bottom (10 between circles, 14 between groups)

| screen (closed) | column |
|---|---|
| root places | Inbox, Sent, Calendar, Settings (the four circles under the status cluster at 168) · [16] · the view switch as a capsule stood on end · Spacer · Compose (accent) at the foot, 24 up |
| Settings | Inbox alone (the one way home); the others return with the next place |
| Trash | the four + Trash while you are in it |
| composer / reply / forward | Close · Send (accent) · [14] · Attach (a menu: photos, files) · Formatting (accent stroke while its bar is up) |
| invite form / edit event | Close · Send |
| reader | Back · ⋯ (menu) · [14] · Speak (accent) · Type · [14] · Reply all · Reply · Forward; in Trash: Back · ⋯ · [14] · Forward |
| opened event | no column: its own Back row; still a page, for the sheet's card and top gap |

| screen (open) | side bar |
|---|---|
| root places | the five places at 48 · Spacer · (a view switch only if the product wants it there) · Spacer · Compose at the foot |
| reader cover | the places · [14] · Reply all · Reply · Forward as extras · Compose; the capsule rests; a place tapped closes the letter (`onChange(of: tab) { close() }`); no microphone (the wide pane has no voice) |

Apple's reasoning behind the order: navigation first, then the prominent
action, then groups "with a vertical space between items from the top and
bottom bars"; creation sits at the foot under the thumb.

### The page around the column

- Header: the title at 15 medium over a status line at 11.5 muted ("Draft
  saved", "Guests get an email"), centred, one line each, 8 above and 12
  below; no Cancel, no Done — they are circles. The reader has no header
  at all on the closed Duo: 12pt of air, then the letter (Back is in the
  column).
- The paper stops at `pageInset` (88) through `DuoColumnFrame`; a list
  under the root strip stops at `contentInset` (76) and its own trailing
  row padding drops from 12 to 2, so rows gain the column's slack.
- The foot's one object (a quick-reply field, a voice bar) is off by
  default; the Speak or Type circle brings it in on the tab spring
  (`.spring(duration: 0.36, bounce: 0)`, `.easeOut(0.2)` under Reduce
  Motion) and it leaves when idle — the clip finished, the field left
  empty. The keyboard's own bar (formatting) stays with the keyboard.
- A cover picture at the top of a page runs under the column (ignores the
  trailing inset, drawn `width + inset` wide) so the glass circles float on
  it instead of standing beside a hard edge.

### The strip's motion

- Arrives and leaves with `.move(edge: .trailing).combined(with: .opacity)`;
  the side bar with `.leading`; Reduce Motion → `.opacity`. The chrome
  swap itself runs on `.timingCurve(0.32, 0.72, 0, 1, duration: 0.4)`.
- A pushed panel (a settings sub-page) hides the strip as it hides the
  phone's bar: a `chromeHidden` flag set in `onChange(of: path)` on the
  same curve; the strip offsets out by its width + 24, fades, and stops
  hit-testing. Back brings it in the same way.
- Place changes animate the accent between circles on the tab spring; the
  view-switch capsule slides its accent wash (13% accent fill, matched
  geometry) between the two tabs.
- The tab capsule stood on end: width = the circle size; each tab
  (size − 8) × 48 inside a 44 column, (size − 10) × 52 inside a 48 one;
  4 or 5 of padding; the whole capsule shares the circles' glass container.

### The side bar's own numbers

72 wide; 16 above the first place; 10 between places; extras start 14
under the places; `Spacer(minLength: 16)` on either side of the capsule;
24 below the foot circle; `frame(maxHeight: .infinity)`. Beside it, a
reader pane keeps 8 leading, 24 trailing, 8 top.

### The heading on the open pose

The masthead carries the phone's 44pt search circle (there is no bar to
hold a magnifier); while the field is up, or a term is set, the address
line under the title folds on the masthead's swap transition — on every
screen and every width, because the line says which addresses you are
browsing and a search is not asking that.
