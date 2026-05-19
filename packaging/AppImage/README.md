# Surypus ERP — AppImage Packaging

## Prerequisites

- Qt 6.7+ installed with Quick, QuickControls2, Charts modules
- CMake 3.21+
- wget (for downloading linuxdeploy tools)
- fuse3 or appimaged (for running AppImages)

## Build

```bash
cd packaging/AppImage
./package-appimage.sh
```

The output AppImage will be in `../../dist/`.

## Run

```bash
./dist/Surypus_ERP-*.AppImage
```

The backend API server must be running on localhost:3000 for the app to function.
Start it with:
```bash
cd surypus-api
stack exec surypus-api
```

## Requirements

- Linux x86_64
- FUSE for AppImage execution (install `fuse3` on Ubuntu/Debian, `fuse` on Fedora)