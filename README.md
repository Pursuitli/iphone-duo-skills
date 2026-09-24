# iphone-duo-fit

An agent skill that fits an existing iPhone app to the **iPhone Duo**,
Apple's foldable (announced 2026-09-09, on sale 2026-10-23, simulator in
Xcode 27.1). Load it and your coding agent knows how to make every screen
right in every pose:

| pose | window | what changes |
|---|---|---|
| closed | 466 × 678 pt | the system owns a vertical column on the right; your bar's controls move into it, on the camera's axis |
| open, upright | 626 × 890 pt | tablet-class layout with the bar as a side bar; no phone chrome stretched to 626 |
| open, on its side | 890 × 626 pt | a split, with the pane running under the reserved column |
| fold / unfold mid-task | | the screen keeps its identity and state |

It covers **SwiftUI** apps and **web / Capacitor** apps, with the same
numbers for both. Everything in it was measured on the Duo simulator pixel
by pixel while shipping a mail app; the traps have their tells written next
to them (the one where every button is 8pt off because a screen is a
`.sheet`, the one where a zoom wrapper clips the column away, the one where
a 768 breakpoint stretches the phone layout across the open display).

## Install

Claude Code, as a plugin:

```bash
claude plugin marketplace add Pursuitli/iphone-duo-skills
claude plugin install iphone-duo-fit@iphone-duo-skills
```

Any agent that reads the [Agent Skills](https://agentskills.io) format
(Claude Code, Codex, Cursor, Gemini CLI, …):

```bash
npx skills add Pursuitli/iphone-duo-skills
```

Or copy `skills/iphone-duo-fit/` into `~/.claude/skills/` (or your
project's `.claude/skills/`).

## Use

Ask for what you want and the skill triggers on it:

- "Audit this app for the iPhone Duo and fix every pose."
- "The buttons on the folded Duo don't line up with the clock."
- "Our tab bar is stretched across the whole screen when the phone is open."
- "Make this Capacitor app work on the Duo."

The agent will audit the screen × pose matrix first
(`references/audit.md`), then fix in order: width-measured layout, the
device question, the closed pose's column, the open pose's side bar and
split, the fold. It measures screenshots with `scripts/measure_column.py`
rather than eyeballing them.

## What is in it

```
skills/iphone-duo-fit/
├── SKILL.md                  the four decisions, on one page
├── references/
│   ├── device-facts.md       sizes, size classes, the system column's metrics, simulator facts
│   ├── swiftui.md            the native recipe, with code
│   ├── web.md                React / Capacitor / CSS recipe
│   └── audit.md              the screen × pose matrix, checklist, XCTest axis check
└── scripts/
    ├── audit_code.sh         lists layout decisions made from the wrong signal
    ├── duo-sim.sh            create / boot / launch / screenshot your own Duo simulator
    └── measure_column.py     measures a closed-Duo screenshot's column against the Wi-Fi ring
```

## Numbers you will keep coming back to

- Breakpoints by measured window width: **600** (top bar / side bar arrives),
  **840** (split), 1120 (density only).
- The closed Duo's reserved column: ≈ 85pt trailing safe inset; the status
  cluster ends ≈ 152pt down; the hardware axis is **48pt** from the trailing
  edge; the system's capsule is **44pt**; the first app control starts at
  **168pt**.
- A `.sheet` on the outer display is a card **8pt** inside the screen. Every
  presented screen on the closed Duo is a `fullScreenCover`.

## Licence

MIT. Contributions welcome, especially measurements from real hardware once
it ships; say what you measured and how.
