# Unify

Unify is a web app aggregator built with Qt 6, Qt WebEngine, and Kirigami. It organizes "services" (web apps) by "workspaces" and opens each service in a WebView with desktop-friendly integrations (notifications, screen sharing, etc.).

## Requirements

- Qt 6 (Quick, Qml, QuickControls2, WebEngineQuick, DBus)
- KDE Frameworks 6 (Kirigami, I18n, CoreAddons, IconThemes, Notifications)
- Extra CMake Modules (ECM)
- CMake 3.24+ and a C++17+ compiler
- gettext (optional, for i18n via `Messages.sh`)

On a recent KDE/Qt distro, install the development packages matching the modules above.

## Project Structure (overview)

- `src/`: C++ sources (`main.cpp`, `configmanager.*`)
- `src/qml/`: QML UI (`Main.qml`) and components
- `po/`: localization tooling and CMake integration
- `CMakeLists.txt` and `src/CMakeLists.txt`: build configuration
- `io.github.denysmb.unify.desktop`, `io.github.denysmb.unify.metainfo.xml`: app metadata

## Build

Debug (recommended for development):

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j
```

Run:

```bash
./build/bin/unify
```

Release (optional):

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build
```

## Localization (optional)

Generate/update translation catalogs (requires gettext):

```bash
./Messages.sh
```

## Development Notes

- C++ style follows `.clang-format`; the clang-format pre-commit hook is configured via CMake.
- QML is organized across `src/qml/components`, dialogs in `src/qml/dialogs`, and JS utils in `src/qml/utils`.
- Qt Test is available if you want to add tests later (CTest integration supported).
