# The audit: every screen in every pose

Build this before changing code, fill it in as you go, and put it in the
summary you hand back. A fitted app is one where every cell is right.

## 1. The matrix

Rows: every screen the app can show. Not only the root places — every
pushed screen, every sheet, every full-screen cover, every alert and menu,
every empty state, every keyboard-up state. Enumerate them from the code
(`grep -n "\.sheet(\|fullScreenCover(\|NavigationLink\|navigationDestination\|\.alert(\|confirmationDialog(" `
for SwiftUI; routes and modal components for the web), not from memory.

Columns:

| pose | window | layout | chrome |
|---|---|---|---|
| closed | 466 × 678 | phone | strip in the system's column |
| open upright | 669 × 951 | tablet | side bar |
| open on its side | 951 × 669 | split | side bar + the pane under the column |
| **closed → open** mid-task | | | state kept, chrome swaps on its curve |
| **open → closed** mid-task | | | state kept, presented screens re-host as pages |

For each cell record: what draws, what is wrong, the measured numbers where
alignment matters, and the fix's commit.

## 2. The checklist per screen

Closed pose:
- [ ] The screen's controls stand in the column, 44pt, centred 48pt from the
      trailing edge, the first 168pt down; groups in Apple's order
      (navigation, prominent action, then groups with a 14pt gap).
- [ ] No "Cancel" / "Done" words on the header; the header carries the title
      alone.
- [ ] Content stops at the content inset (76pt from the edge for lists and
      root places, 88pt for a presented page's paper) and runs to the foot.
- [ ] Presented as `fullScreenCover`, not `.sheet` (no 8pt band, no top gap).
- [ ] Nothing under the camera or the clock: the top-right corner of the
      content is clear of the status cluster.
- [ ] A foot object (input bar) appears only on request and leaves when idle.
- [ ] The column is not clipped by a transition wrapper.

Open upright:
- [ ] Tablet layout, one column; the side bar on the leading edge, icons
      only, names as accessibility labels, nothing shrunk.
- [ ] No top bar wrapping its words at 669.
- [ ] Search / address lines fold sensibly: when a search field is up, the
      subtitle line goes.

Open on its side:
- [ ] Split; the pane runs under the reserved column and only its title row
      keeps clear of the clock (~80pt).
- [ ] A fixed-measure pane keeps its measure; the grid beside it gains the
      column's room.
- [ ] The pane's verbs stack with their words under 480pt of pane; the
      sender / meta row runs the whole width with its trailing controls at
      the far end.
- [ ] The pane does not grow to its content (a Cc line, long pills).

Transitions:
- [ ] Fold mid-letter: the letter is still open, at the same scroll.
- [ ] Unfold mid-compose: the draft text is intact; the composer beside a
      list becomes the page.
- [ ] Rotate on the open pose: split ↔ tablet with the open item kept.
- [ ] Reduce Motion: the swap fades instead of sliding.

## 3. Measuring a screenshot

```bash
xcrun simctl io <your-duo-udid> screenshot inbox.png       # the reference
xcrun simctl io <your-duo-udid> screenshot reader.png      # the screen under test
python3 scripts/measure_column.py inbox.png reader.png
```

Reading the output:
- The system's Wi-Fi ring appears around `top ≈ 110, height ≈ 32,
  centre ≈ 48`. That is the axis; if it does not read 48 the screenshot is
  not a closed Duo at 3× (pass `--scale`).
- Every app control should read `centre 48 ± 1.5`, `height ≈ 44`. A
  column at `56` with the first control at `177` instead of `168–169` is the
  sheet trap.
- The first line after a second file compares its first control against the
  reference's: `dx +0.0 dy +0.0` is the goal.
- A blob at `top 0, height ≈ 70, centre ≈ 39` is the rounded corner the
  simulator paints; ignore it.

Poses: only the Simulator app's Device Hub sets them, so the open pose is a
person's screenshot; measure it the same way for the side bar (the script
takes `--axis` and works from the trailing edge, so for a leading-edge side
bar mirror the image first: `python3 -c "from PIL import Image, ImageOps; ImageOps.mirror(Image.open('open.png')).save('open-m.png')"`).

## 4. The XCTest axis check

Keep the alignment true after you leave. One helper, called by every test
that opens a screen on the Duo:

```swift
func checkOnAxis(_ labels: [String], first: String) {
    let w = app.frame.width
    for label in labels {
        let b = app.buttons[label]
        guard b.exists else { continue }
        let dx = w - b.frame.midX
        XCTAssert(abs(dx - 48) <= 1.5, "\(label) centred \(dx)pt from the edge, not 48")
    }
    let f = app.buttons[first]
    if f.exists { XCTAssert(abs(f.frame.midY - 190) <= 1.5, "\(first) centred \(f.frame.midY)pt down, not 190") } // 168 + 22
}
```

Run on a simulator you booted yourself; a UI test against a device someone
else has open in Xcode takes over their screen. Pass secrets to the runner
as `TEST_RUNNER_<NAME>` in the environment of `xcodebuild test`, never in a
file. Captures written by the runner may only land in its own container;
copy them out with `simctl get_app_container <udid> <bundle>.xctrunner data`.

## 5. What to hand back

- The matrix, filled.
- For each fix: the screen, the pose, the tell, the change, the measurement
  after.
- What remains: usually the fold ↔ unfold morph (a slide, not a matched
  morph), unread hinge regions, and anything only seen on a stand-in.
- Whether a twin exists: a product shipping both a web app and a native app
  fixes both with the same numbers, and says so.
