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
| a screen's controls sit under the camera | a `NavigationStack` root did not get the shell's inset | top up to `contentInset` on that screen |
| two presented screens' columns differ by 2pt | each did its own offset arithmetic | one shared `DuoColumnFrame` |
| the phone chrome stretched across the open display | a 768 breakpoint | 600 |
| an iPad shows the Duo's strip | Duo detected by width | ask the device |
| the pane "sometimes overflows" | it measured its drawn width to choose its words | read the offered width at its root |
| the top bar wraps its words at 669 | a bar designed for 834 | the side bar on the Duo |
| open state lost on a fold | a screen built once per layout branch | one place with structural identity; open state as data |
| the bar minimises on the Duo | the minimiser runs under every chrome | return unless chrome == .bar |
| "Executed 0 tests" | Swift Testing target | read the `.xcresult` summary |
