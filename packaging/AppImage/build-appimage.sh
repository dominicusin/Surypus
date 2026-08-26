#!/bin/bash
# Build a Surypus QML AppImage (issue #11)
# Requires: linuxdeployqt, Qt5/Qt6, appimagetool (from AppImageKit).
set -euo pipefail

APP=surypus
VERSION="${1:-$(date +%Y.%m.%d)}"
WORKDIR="$(mktemp -d)"
APPDIR="${WORKDIR}/${APP}.AppDir"

mkdir -p "${APPDIR}/usr/bin" "${APPDIR}/usr/share/${APP}/qml"

# 1. Copy the QML frontend (relative paths preserved so `import "components"` works)
cp -r frontend/qml/* "${APPDIR}/usr/share/${APP}/qml/"

# 2. Desktop + icon + AppRun
cp packaging/AppImage/surypus.desktop "${APPDIR}/${APP}.desktop"
cp packaging/AppImage/surypus.png     "${APPDIR}/${APP}.png" 2>/dev/null || true
cp packaging/AppImage/AppRun          "${APPDIR}/AppRun"
chmod +x "${APPDIR}/AppRun"

# 3. Bundle Qt plugins/libs via linuxdeployqt
linuxdeployqt "${APPDIR}/${APP}.desktop" \
  -qmake=$(command -v qmake qmake-qt5 qmake6 2>/dev/null | head -1) \
  -appimage -no-translations -verbose=2

mv "${APP}-${VERSION}-x86_64.AppImage" "./${APP}-${VERSION}-x86_64.AppImage"
echo "Built: ${APP}-${VERSION}-x86_64.AppImage"
