# Surypus QML AppImage (issue #11)

Packages the QtQuick desktop frontend (`frontend/qml/`) into a portable Linux AppImage.

## Prerequisites
- Qt 5.15+ (qml / qmlscene)
- `linuxdeployqt`
- `appimagetool` (AppImageKit)

## Build
```bash
bash packaging/AppImage/build-appimage.sh [VERSION]
```

Produces `surypus-<VERSION>-x86_64.AppImage`.

## Layout inside the AppImage
```
surypus.AppDir/
  AppRun                       # launches Main.qml via qml/qmlscene
  surypus.desktop
  surypus.png
  usr/share/surypus/qml/       # copied frontend/qml tree
  usr/lib/  usr/lib/qt5/plugins/   # Qt bundled by linuxdeployqt
```

The Haskell backend (`surypus-server`) is a separate service; this AppImage ships the
desktop UI only and connects to a running API endpoint.
