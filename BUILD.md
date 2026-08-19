## Build

### Prerequisites

- CMake 3.20 or higher
- Qt6 (Core, Quick, Gui, Qml, QuickControls2, Widgets, WebEngineQuick, PrintSupport, Pdf, Test)
- KDE Frameworks 6 (Kirigami, KirigamiAddons, I18n, CoreAddons, QQC2DesktopStyle, IconThemes, Notifications, Service, KIO, DBusAddons, Archive)
- Extra CMake Modules (ECM)
- C++17 compatible compiler
- Git
- gettext (optional, for translations)

### Build Instructions

1. **Clone the repository:**
   ```bash
   git clone https://invent.kde.org/denysmb/Unify.git
   cd Unify
   ```

2. **Configure the build:**
   ```bash
   cmake -B build -DCMAKE_INSTALL_PREFIX=~/.local
   ```

   For debug builds (recommended for development):
   ```bash
   cmake -B build -DCMAKE_INSTALL_PREFIX=~/.local -DCMAKE_BUILD_TYPE=Debug
   ```

3. **Build:**
   ```bash
   cmake --build build -j
   ```

4. **Install:**
   ```bash
   cmake --install build
   ```

5. **Update desktop database and icon cache:**
   ```bash
   update-desktop-database ~/.local/share/applications/
   gtk-update-icon-cache ~/.local/share/icons/hicolor/
   ```

6. **Run:**
   ```bash
   ~/.local/bin/unify
   ```
   Or search for "Unify" in your application launcher.

### System-wide Installation

For system-wide installation, omit the `CMAKE_INSTALL_PREFIX` and use sudo for install:
```bash
cmake -B build
cmake --build build -j
sudo cmake --install build
sudo update-desktop-database
sudo gtk-update-icon-cache /usr/share/icons/hicolor/
```

### Development

For development, you can run directly from the build directory without installing:
```bash
./build/bin/unify
```

#### Localization

Generate/update translation catalogs (requires gettext):
```bash
./Messages.sh
```

#### Code Style

The project uses clang-format for C++ code formatting. A pre-commit hook is automatically configured via CMake to ensure code style compliance.
