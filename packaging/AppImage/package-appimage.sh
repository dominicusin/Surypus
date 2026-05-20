#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_DIR/qml/build-appimage"
APPDIR="$BUILD_DIR/AppDir"
OUTPUT_DIR="$PROJECT_DIR/dist"

echo "=== Surypus ERP AppImage Builder ==="
echo "Project: $PROJECT_DIR"

# --- Prerequisites ---
command -v cmake >/dev/null 2>&1 || { echo "ERROR: cmake required"; exit 1; }
command -v wget >/dev/null 2>&1 || { echo "ERROR: wget required for downloading linuxdeploy"; exit 1; }

LINUXDEPLOY="$BUILD_DIR/linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_QT="$BUILD_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"

download_if_missing() {
    local url="$1"
    local dest="$2"
    if [ ! -f "$dest" ]; then
        echo "Downloading $(basename $dest)..."
        wget -q "$url" -O "$dest"
        chmod +x "$dest"
    else
        echo "Found $(basename $dest), skipping download"
    fi
}

mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

download_if_missing \
    "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage" \
    "$LINUXDEPLOY"

download_if_missing \
    "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage" \
    "$LINUXDEPLOY_QT"

# --- Build the application ---
echo "=== Building surypus-dashboard ==="
cmake -S "$PROJECT_DIR/qml" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr
cmake --build "$BUILD_DIR" --parallel "$(nproc)"

# --- Copy icon ---
# Use a simple SVG icon; generate a placeholder if none exists
ICON_SRC="$PROJECT_DIR/packaging/AppImage/surypus-dashboard.svg"
if [ ! -f "$ICON_SRC" ]; then
    echo "Creating placeholder icon..."
    cat > "$ICON_SRC" << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="32" fill="#0078D4"/>
  <text x="128" y="160" font-size="120" font-weight="bold" fill="white" text-anchor="middle" font-family="sans-serif">S</text>
</svg>
SVGEOF
fi

# --- Package into AppImage ---
echo "=== Packaging AppImage ==="
export QML_SOURCES_PATHS="$PROJECT_DIR/qml"

"$LINUXDEPLOY" \
    --appdir "$APPDIR" \
    --plugin qt \
    --executable "$BUILD_DIR/surypus-dashboard" \
    --desktop-file "$SCRIPT_DIR/surypus-dashboard.desktop" \
    --icon-file "$ICON_SRC" \
    --output appimage \
    2>&1 | tee "$BUILD_DIR/linuxdeploy.log"

# Move AppImage to dist/
# The linuxdeploy output filename is derived from the desktop file or cmake project name
mv -v "$BUILD_DIR"/surypus-dashboard-*.AppImage "$OUTPUT_DIR/" 2>/dev/null || true
# Fallback: move any AppImage files in BUILD_DIR
find "$BUILD_DIR" -maxdepth 1 -name '*.AppImage' -not -name 'linuxdeploy*' -exec mv -v {} "$OUTPUT_DIR/" \; 2>/dev/null || true

echo "=== Done ==="
echo "AppImage: $(ls -lh $OUTPUT_DIR/*.AppImage 2>/dev/null || echo 'Not found in OUTPUT_DIR')"
ls -la "$OUTPUT_DIR/"