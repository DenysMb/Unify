<div align="center">
  <img src="src/assets/unify.svg" width="128" height="128" alt="Unify Icon"/>
  
  # Unify
  
  **Web app aggregator for KDE Plasma**
  
  Organize and manage your web services with desktop-friendly integrations
  
</div>

---

## About

Unify is a native KDE application that brings your favorite web services to the desktop with seamless integration. Built with Qt 6, Qt WebEngine, and Kirigami, it organizes web apps by workspaces and provides desktop-friendly features like notifications, screen sharing, and more.

### Features

- **Workspace organization** - Group related web services into customizable workspaces
- **Desktop integrations** - Native notifications, screen sharing, media capture support
- **DRM content support** - Play protected content from Spotify, Netflix, Prime Video, and Tidal with Widevine
- **Privacy controls** - Isolated profiles option for separate cookies and storage per service
- **Auto-granted permissions** - Seamless experience with pre-configured permissions for your services
- **Native KDE integration** - Built with Qt/QML and Kirigami for seamless Plasma desktop experience
- **Persistent sessions** - Your login sessions and preferences are saved between restarts

## Installation

### Flathub (Recommended)

The easiest way to install Diktate is through Flathub:

[![Download on Flathub](https://flathub.org/api/badge?svg)](https://flathub.org/apps/io.github.denysmb.unify)

Or via command line:
```bash
flatpak install flathub io.github.denysmb.unify
```


### Building from Source

For build instructions, see [BUILD.md](BUILD.md).

## Screenshots

<img src="https://raw.githubusercontent.com/DenysMb/Unify/refs/heads/main/screenshots/screenshot_webview.png" alt="Unify Screenshot" />

## DRM Content Support (Widevine)

To play DRM-protected content from services like Spotify, Prime Video, Netflix, and Tidal, you need to install the Widevine CDM (Content Decryption Module).

All you need to do is go to `Tips > Install Widevine`.

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

## License

This project is licensed under the GPL-3.0 License - see the LICENSE file for details.
