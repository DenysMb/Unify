# Unify

Unify is a web app aggregator built with Qt 6, Qt WebEngine, and Kirigami. It organizes "services" (web apps) by "workspaces" and opens each service in a WebView with desktop-friendly integrations (notifications, screen sharing, etc.).

<img src="https://raw.githubusercontent.com/DenysMb/Unify/refs/heads/main/screenshots/screenshot_webview.png" />

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

## DRM Content Support (Widevine)

To play DRM-protected content from services like Spotify, Prime Video, Netflix, and Tidal, you need to install the Widevine CDM (Content Decryption Module).

**For Flatpak users:**

Run the installation script:

```bash
./install-widevine.sh
```

This script:
- Downloads the latest Widevine CDM from Firefox's official repository
- Installs it to `~/.var/app/io.github.denysmb.unify/plugins/WidevineCdm/`
- Configures Qt WebEngine to use the library

After installation, restart Unify for changes to take effect.

**To uninstall:**

```bash
./install-widevine.sh uninstall
```

**Dependencies:** wget or curl, unzip, flatpak, jq or python

**Note:** Widevine is proprietary software owned by Google and cannot be distributed with the application.

## Permissions & Privacy

Unify automatically grants certain browser permissions to configured services for seamless functionality:

- Geolocation
- Media capture (audio/video)
- Screen and window sharing
- Notifications
- Clipboard access

These permissions are auto-granted because users have explicitly chosen to add and use each service. If you need more isolation between services, you can enable `isolatedProfile: true` for a service to use separate cookies and storage.

**Data Storage:**
- Cookies and localStorage are persisted via Qt's WebEngineProfile
- Storage location: `~/.local/share/io.github.denysmb/Unify/` (or Flatpak equivalent, like `~/.var/app/io.github.denysmb.unify/data/io.github.denysmb/Unify/`)
- Unify does not collect or transmit any user data to third-party servers

**Network Traffic:**
- Unify does not proxy or intercept network traffic
- All web services communicate directly with their respective servers

For more details, see [SECURITY.md](SECURITY.md).

## Development Notes

- C++ style follows `.clang-format`; the clang-format pre-commit hook is configured via CMake.
- QML is organized across `src/qml/components`, dialogs in `src/qml/dialogs`, and JS utils in `src/qml/utils`.
- Qt Test is available if you want to add tests later (CTest integration supported).
