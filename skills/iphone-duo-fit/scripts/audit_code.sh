#!/usr/bin/env bash
# List the layout decisions in a repo that are made from the wrong signal
# for the iPhone Duo. Run from the repo root; pass paths to narrow it.
#
#   scripts/audit_code.sh [path ...]
#
# Each hit is a place to read, not necessarily a bug: a size class is fine
# for a font, wrong for "is this a split". The Duo's inner display reports
# regular size classes both ways, its idiom is .phone in every pose,
# UIScreen.main is the OUTER display even when open, and the inner display
# ignores supported orientations — so each of these answers a question
# other than "how wide is my window".
set -uo pipefail
PATHS=("${@:-.}")
G="grep -rnE --include=*.swift --include=*.m --include=*.ts --include=*.tsx --include=*.css --include=*.plist"
$G --exclude-dir=node_modules --exclude-dir=.build --exclude-dir=DerivedData --exclude-dir=dist \
  -e 'horizontalSizeClass|verticalSizeClass|userInterfaceIdiom|UIScreen\.main|interfaceOrientation|UIDevice\.current\.orientation|isPortrait|isLandscape' \
  -e 'UIRequiresFullScreen' \
  -e '\bmd:|min-width:\s*768|min-width:\s*1024|BREAKPOINT|breakpoint' \
  "${PATHS[@]}" 2>/dev/null | sed 's/^/  /'
echo
echo "Presented screens (each needs a closed-Duo host decision: page, not sheet):"
grep -rnE --include=*.swift --exclude-dir=.build --exclude-dir=DerivedData -e '\.sheet\(|fullScreenCover\(|\.popover\(' "${PATHS[@]}" 2>/dev/null | sed 's/^/  /'
echo
echo "Clipping wrappers that can cut a column off:"
grep -rnE --include=*.swift --exclude-dir=.build --exclude-dir=DerivedData -e '\.clipped\(\)|clipShape\(' "${PATHS[@]}" 2>/dev/null | sed 's/^/  /'
