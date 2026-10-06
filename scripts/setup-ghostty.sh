#!/usr/bin/env bash
# Vendors libghostty (GhosttyKit) into vendor/ghostty as a thin static library
# plus the C header + module map, so the Xcode project can `import GhosttyKit`.
#
# By default, builds the pinned upstream source in vendor/ghostty-src.
# Explicit development overrides: GHOSTTY_SRC, or GHOSTTYKIT together with
# GHOSTTY_RESOURCES (the matching build's zig-out/share directory).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/vendor/ghostty"
ARCH="${ARCH:-$(uname -m)}"
# shellcheck source=ghostty-version.env
source "$ROOT/scripts/ghostty-version.env"
export ZIG_GLOBAL_CACHE_DIR="${ZIG_GLOBAL_CACHE_DIR:-$ROOT/vendor/zig-cache}"

zig_for() {
  local version zig target checksum archive dir
  version="$(sed -n 's/.*minimum_zig_version = "\([^"]*\)".*/\1/p' "$1/build.zig.zon")"
  if [ -n "${ZIG:-}" ]; then
    zig="$ZIG"
  else
    [ "$version" = "$GHOSTTY_ZIG_VERSION" ] || {
      echo "This checkout needs Zig $version; set ZIG to that compiler." >&2; return 1;
    }
    case "$(uname -m)" in
      arm64) target=aarch64; checksum="$GHOSTTY_ZIG_ARM64_SHA256" ;;
      x86_64) target=x86_64; checksum="$GHOSTTY_ZIG_X86_64_SHA256" ;;
      *) echo "Unsupported Zig host architecture" >&2; return 1 ;;
    esac
    dir="$ROOT/vendor/zig/$version"
    zig="$dir/zig"
    if [ ! -x "$zig" ]; then
      mkdir -p "$dir"
      archive="$(mktemp "$ROOT/vendor/zig/archive.XXXXXX")"
      curl --fail --location --retry 3 "https://ziglang.org/download/$version/zig-$target-macos-$version.tar.xz" -o "$archive" >&2 || return 1
      printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 -c - >&2 || return 1
      tar -xJf "$archive" --strip-components=1 -C "$dir" || return 1
      rm "$archive"
    fi
  fi
  [ "$("$zig" version)" = "$version" ] || {
    echo "Ghostty requires exactly Zig $version (compiler: $zig)" >&2; return 1;
  }
  echo "$zig"
}

build_xcframework() {
  local zig
  zig="$(zig_for "$1")" || return 1
  # Ghostty compiles its Metal shaders, and Xcode ships the Metal compiler as
  # a separate download.
  xcrun -sdk macosx metal --version >/dev/null 2>&1 || xcodebuild -downloadComponent MetalToolchain >&2 || return 1
  (cd "$1" && "$zig" build -Demit-xcframework=true -Dxcframework-target=native -Demit-macos-app=false -Doptimize=ReleaseFast >&2) || return 1
}

SRC=""
COMMIT=unknown
ZIG_VERSION=unknown
DIRTY=true
if [ -n "${GHOSTTYKIT:-}" ]; then
  XCF="$GHOSTTYKIT"
  RESOURCES="${GHOSTTY_RESOURCES:?Set GHOSTTY_RESOURCES to the matching zig-out/share directory}"
else
  SRC="${GHOSTTY_SRC:-$ROOT/vendor/ghostty-src/$GHOSTTY_COMMIT}"
  if [ -z "${GHOSTTY_SRC:-}" ]; then
    if [ ! -d "$SRC" ]; then
      mkdir -p "$(dirname "$SRC")"
      git init --quiet "$SRC"
      git -C "$SRC" remote add origin https://github.com/ghostty-org/ghostty.git
      git -C "$SRC" fetch --quiet --depth=1 origin "$GHOSTTY_COMMIT"
      git -C "$SRC" checkout --quiet --detach FETCH_HEAD
    fi
    [ "$(git -C "$SRC" rev-parse HEAD)" = "$GHOSTTY_COMMIT" ] || {
      echo "Pinned Ghostty checkout has an unexpected revision: $SRC" >&2; exit 1;
    }
    git -C "$SRC" diff --quiet HEAD -- || {
      echo "Pinned Ghostty checkout has local changes; refusing to overwrite them." >&2; exit 1;
    }
  fi
  build_xcframework "$SRC"
  XCF="$SRC/macos/GhosttyKit.xcframework"
  RESOURCES="$SRC/zig-out/share"
  COMMIT="$(git -C "$SRC" rev-parse HEAD)"
  ZIG_VERSION="$(sed -n 's/.*minimum_zig_version = "\([^"]*\)".*/\1/p' "$SRC/build.zig.zon")"
  if git -C "$SRC" diff --quiet HEAD --; then DIRTY=false; fi
fi

SLICE="$(find "$XCF" -maxdepth 1 -type d -name 'macos-*' | head -1)"
[ -n "$SLICE" ] || { echo "No macOS slice in $XCF" >&2; exit 1; }
LIB="$(find "$SLICE" -maxdepth 1 -name '*.a' | head -1)"
[ -f "$LIB" ] && [ -f "$SLICE/Headers/ghostty.h" ] || {
  echo "Incomplete GhosttyKit framework: $SLICE" >&2; exit 1;
}
for resource in terminfo/78/xterm-ghostty ghostty/themes ghostty/shell-integration/zsh/ghostty-integration; do
  [ -e "$RESOURCES/$resource" ] || { echo "Missing Ghostty resource: $RESOURCES/$resource" >&2; exit 1; }
done

echo "Using $LIB"
mkdir -p "$OUT/lib" "$OUT/include" "$OUT/resources" "$OUT/notices"
if lipo -info "$LIB" | grep -q 'Architectures in the fat file'; then
  lipo "$LIB" -thin "$ARCH" -output "$OUT/lib/libghostty.a"
else
  cp "$LIB" "$OUT/lib/libghostty.a"
fi
# Xcode 26 treats every argument after -verify_arch as an architecture.
lipo "$OUT/lib/libghostty.a" -verify_arch "$ARCH"
cp "$SLICE/Headers/ghostty.h" "$OUT/include/ghostty.h"
cat > "$OUT/include/module.modulemap" <<'MAP'
module GhosttyKit {
    umbrella header "ghostty.h"
    export *
}
MAP
rsync -a --delete "$RESOURCES/terminfo/" "$OUT/resources/terminfo/"
rsync -a --delete --exclude doc "$RESOURCES/ghostty/" "$OUT/resources/ghostty/"
if [ -n "$SRC" ]; then
  python3 "$ROOT/scripts/collect-notices.py" "$OUT/notices/Ghostty.txt" \
    Ghostty "$SRC" Zig-dependencies "$ZIG_GLOBAL_CACHE_DIR/p"
elif [ -n "${GHOSTTY_NOTICES:-}" ]; then
  cp "$GHOSTTY_NOTICES" "$OUT/notices/Ghostty.txt"
else
  echo "Prebuilt development override: set GHOSTTY_NOTICES to supply dependency notices." >&2
fi
python3 - "$OUT/build-info.json" "$COMMIT" "$ZIG_VERSION" "$ARCH" "$DIRTY" <<'PY'
import json
import sys
from pathlib import Path
path, commit, zig, arch, dirty = sys.argv[1:]
Path(path).write_text(json.dumps({"commit": commit, "zig": zig, "arch": arch, "dirty": dirty == "true"}, indent=2) + "\n")
PY
du -sh "$OUT/lib/libghostty.a"
