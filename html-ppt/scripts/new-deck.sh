#!/usr/bin/env bash
# html-ppt :: new-deck.sh — scaffold a new deck with its assets attached
#
# Usage:
#   new-deck.sh <name> [parent-dir] [--link]
#
# By DEFAULT the skill's shared assets/ is COPIED next to the deck, so the deck
# folder is self-contained and portable anywhere — another drive, a USB stick,
# a zip you mail to someone. Use --link to instead reference the skill's assets
# in place (handy while iterating on base.css or a theme; not portable).

set -euo pipefail

NAME=""
PARENT="."
LINK=0
for arg in "$@"; do
  case "$arg" in
    --link|-Link|--Link) LINK=1 ;;
    *)
      if [[ -z "$NAME" ]]; then NAME="$arg"; else PARENT="$arg"; fi
      ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "usage: new-deck.sh <name> [parent-dir] [--link]" >&2
  exit 1
fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$HERE/templates/deck.html"
ASSETS="$HERE/assets"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "error: template not found at $TEMPLATE" >&2
  exit 1
fi
if [[ ! -d "$ASSETS" ]]; then
  echo "error: assets not found at $ASSETS" >&2
  exit 1
fi

OUT_DIR="$PARENT/$NAME"
if [[ -e "$OUT_DIR" ]]; then
  echo "error: $OUT_DIR already exists" >&2
  exit 1
fi
mkdir -p "$OUT_DIR"

# templates/deck.html references ../assets/...; the deck always reaches its own
# assets through the plain "assets/..." path.
PREFIX="assets"
MODE="copy"

if [[ "$LINK" -eq 1 ]]; then
  # A relative path only exists on the same filesystem root; otherwise fall back
  # to a symlink (which, like a Windows junction, does NOT survive being copied).
  REL="$(python3 -c 'import os,sys;print(os.path.relpath(sys.argv[2],sys.argv[1]))' \
          "$OUT_DIR" "$ASSETS" 2>/dev/null || true)"
  if [[ -n "$REL" && "$REL" != /* && "$REL" != ?:* && "$REL" != ".."*":\\"* ]]; then
    PREFIX="$REL"
    MODE="link-relative"
  elif ln -s "$ASSETS" "$OUT_DIR/assets" 2>/dev/null; then
    MODE="link-symlink"
  else
    # Last resort: an absolute file:// URI. Works only on this machine.
    PREFIX="file://$ASSETS"
    MODE="link-file-uri"
  fi
else
  cp -R "$ASSETS" "$OUT_DIR/assets"
fi

sed "s|\"../assets/|\"$PREFIX/|g" "$TEMPLATE" > "$OUT_DIR/index.html"

echo "✔ created $OUT_DIR/index.html"
case "$MODE" in
  copy)           echo "  assets: copied into $OUT_DIR/assets/  ->  deck is self-contained and portable" ;;
  link-relative)  echo "  assets: linked via relative path  $PREFIX/" ;;
  link-symlink)   echo "  assets: linked via symlink  $OUT_DIR/assets" ;;
  link-file-uri)  echo "  assets: linked via absolute URI  $PREFIX/" ;;
esac

if [[ "$MODE" == "link-symlink" || "$MODE" == "link-file-uri" ]]; then
  echo ""
  echo "WARNING: this deck does not carry its own assets, so it will open as"
  echo "         unstyled HTML once the folder is copied elsewhere. Re-run"
  echo "         without --link if the deck will be shared."
fi

echo ""
echo "next steps:"
echo "  open  $OUT_DIR/index.html"
echo "  # press T to cycle themes, ← → to navigate, O for overview, S for presenter"
