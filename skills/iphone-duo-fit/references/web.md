# The web / Capacitor recipe

A web app on the Duo runs in Safari or in a Capacitor / WKWebView shell.
The webview sees a window whose width changes on a fold or a rotation and
whose safe-area insets carry the system's reserved column; it does not see
poses, hinges or size classes, and it does not need to.

## 1. Breakpoints by measured width, in one place

```ts
export const BP_BAR = 600;    // top bar arrives, bottom bar retires
export const BP_SPLIT = 840;  // the only place a split switches on
export const BP_ROOMY = 1120; // a density, not a layout

function measure(): Layout {
  const w = window.innerWidth;
  if (w >= BP_SPLIT) return "desktop";
  if (w >= BP_BAR) return "tablet";
  return "phone";
}
```

Why: 600 sits under the Duo open upright (626) and the iPad mini (744) and
over the Duo closed (466) and every phone upright; 768 puts the open Duo in
the phone layout stretched to 626 CSS px. 840 sits above the widest iPad in
portrait (834) and under the Duo on its side (890), with ~50px of slack for
browser chrome; the Galaxy Z Fold line lands in the same band (~860–933).

Publish the same threshold to CSS as a named variant (Tailwind v4:
`--breakpoint-bar: 37.5rem`, used as `bar:`), and stop using `md:` for app
layout — it is 768 and will drift from the store.

## 2. The store: `useSyncExternalStore`, and re-measure on more than media queries

```ts
function subscribeWidth(queries: string[], onChange: () => void) {
  const mqs = queries.map((q) => window.matchMedia(q));
  mqs.forEach((mq) => mq.addEventListener("change", onChange));
  let frame = 0;
  const wake = () => {
    if (frame) return;
    frame = requestAnimationFrame(() => { frame = 0; onChange(); });
  };
  window.addEventListener("resize", wake);
  window.addEventListener("orientationchange", wake);
  window.addEventListener("pageshow", wake);
  return () => { /* remove all; do NOT cancel the pending frame */ };
}
```

- Media queries fire once, on the pixel a threshold is crossed. `resize`,
  `orientationchange` and `pageshow` are the belt to those braces: an
  installed-app container on a foldable resized its window without reliably
  delivering the media-query change, and the phone chrome stayed up across
  the inner screen.
- Coalesce to one wake per frame; carry no state, so event order cannot
  matter; the store re-renders only when the resulting string differs.
- Keep the subscribe functions module-level (React re-subscribes whenever it
  is handed a new one), and do not cancel the pending frame in cleanup — a
  wake caught between teardown and re-subscribe left the store stale.
- Server snapshot: the narrow layout; it works at every width and a wider
  client upgrades instead of breaking.

## 3. Safe areas: the reserved column is an inset

```css
:root {
  --sa-top: env(safe-area-inset-top, 0px);
  --sa-right: env(safe-area-inset-right, 0px);
  --sa-bottom: env(safe-area-inset-bottom, 0px);
  --sa-left: env(safe-area-inset-left, 0px);
}
.app-wide { padding-left: calc(1.5rem + var(--sa-left)); padding-right: calc(1.5rem + var(--sa-right)); }
```

- Use `+`, not `max()`: on a closed Duo the right inset is the system's
  column and genuinely eats into the side, as landscape does on other phones.
- Write left and right out as longhands rather than `padding-inline` and an
  override, or the shorthand and its longhand fight over emit order.
- The viewport meta needs `viewport-fit=cover` or the insets read 0.
- A sticky or fixed element on the right edge (a scroll-to-top button, a
  FAB) must pay `--sa-right` too, or it sits under the clock.

## 4. Chrome on the Duo from a webview

A webview cannot stand controls in the system's column the way a native app
does (the column is the native container's safe inset; the page just gets
the inset). Two honest options:

1. **Keep the bottom bar on the closed pose and let the content pay the
   right inset.** The bar's controls stay centred in the *safe* width, which
   is what a person sees as the screen. This is the minimum and it is
   correct.
2. **Draw your own right-edge column** at `right: 0; width: var(--sa-right)`
   with 44px circles centred 48px from the edge, starting 168px down, and
   hide the bottom bar when `--sa-right` is ≥ 64px on a phone-layout window.
   Only do this if the app is a Capacitor shell you control end to end;
   measure it on the simulator against the Wi-Fi ring exactly as a native
   column would be measured (`scripts/measure_column.py` works on any
   1398 × 2034 screenshot).

Either way, on the **open** pose the tablet layout's top bar is what a
browser shows, and it must not wrap at 626px: check every word in it at that
width.

## 5. The fold and the rotation

- Keep both the list and the open item mounted across the layout flip; the
  hidden one `visibility: hidden` and `inert`. A remount restored a stale
  scroll offset once bodies had grown.
- Open state lives in the URL (`?open=<id>`), so the split draws the pane
  from it, the phone keeps it and draws nothing, and a fold or unfold
  mid-letter lands on the same letter.
- Pull-to-refresh gated on "is native" rather than on width means the
  tablet-width Duo in a browser has no pull; if the product wants one there,
  bind only on a coarse pointer and set `overscroll-behavior-y: contain`.

## 6. Testing in a browser

- Chrome DevTools → custom device: 466 × 678 and 626 × 890, DPR 3, mobile
  UA; and 890 × 626 for the side pose. DevTools cannot show the reserved
  column; only the simulator can.
- Drag the responsive width across 600 and 840 slowly and watch that each
  threshold fires exactly once and the chrome swaps without a flash.
- For the Capacitor shell, build the web assets, sync, then follow
  `scripts/duo-sim.sh` — the webview build is measured exactly like the
  native one.
