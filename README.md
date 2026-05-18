# Axion Track — Flutter App
## Professional Fleet Management · Traccar API

---

## Project Structure

```
axion_track/
├── lib/
│   ├── main.dart                    ← Entry point + Splash screen
│   ├── models/
│   │   └── traccar_models.dart      ← All data models (Device, Position, Trip, etc.)
│   ├── services/
│   │   ├── traccar_service.dart     ← REST API + WebSocket client
│   │   └── app_state.dart           ← Global state (Provider)
│   ├── utils/
│   │   └── theme.dart               ← Colors, theme, formatters
│   ├── widgets/
│   │   └── shared_widgets.dart      ← VehicleCard, EventCard, Speedometer, etc.
│   └── screens/
│       ├── login_screen.dart        ← Login + demo shortcut
│       ├── home_screen.dart         ← Bottom nav shell
│       ├── status_screen.dart       ← Vehicle list with filter pills
│       ├── secondary_screens.dart   ← Map, Alerts, Settings
│       ├── live_tracking_screen.dart← Real-time map + speedometer
│       ├── history_screen.dart      ← Trip/stop timeline + playback
│       └── sensors_screen.dart      ← All device attributes
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml      ← Permissions + HTTP cleartext
│       └── res/xml/network_security_config.xml
├── ios/
│   └── Runner/Info.plist            ← iOS permissions + ATS config
└── pubspec.yaml                     ← All dependencies
```

---

## Quick Setup (15 minutes)

### 1. Install Flutter
```bash
# Download from https://flutter.dev/docs/get-started/install
flutter --version   # should show 3.x.x
```

### 2. Create the project shell
```bash
flutter create axion_track --org com.axiontrack --platforms android,ios
cd axion_track
```

### 3. Replace generated files
Copy all files from this package into the project, replacing existing ones:
- Replace `pubspec.yaml`
- Replace `lib/` entirely
- Replace `android/app/src/main/AndroidManifest.xml`
- Add `android/app/src/main/res/xml/network_security_config.xml`
- Replace `ios/Runner/Info.plist`

### 4. Install dependencies
```bash
flutter pub get
```

### 5. Run on device or emulator
```bash
# List available devices
flutter devices

# Run on Android
flutter run -d <android-device-id>

# Run on iOS simulator
flutter run -d <ios-simulator-id>

# Run on all connected devices
flutter run
```

---

## Build APK (Android)

```bash
# Debug APK (for testing)
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk

# Release APK (for distribution)
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Split by ABI (smaller files)
flutter build apk --split-per-abi --release
# Outputs 3 APKs: arm64-v8a, armeabi-v7a, x86_64

# App Bundle (for Play Store)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Install APK directly on phone
```bash
flutter install   # installs on connected device automatically
# OR
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Build IPA (iOS)

```bash
# Requires Xcode on macOS
flutter build ios --release

# Open in Xcode to sign and archive
open ios/Runner.xcworkspace
# In Xcode: Product → Archive → Distribute App
```

---

## Signing (Release APK)

Create `android/key.properties`:
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=/path/to/your/keystore.jks
```

Generate keystore:
```bash
keytool -genkey -v -keystore ~/axion-track.jks -keyalg RSA -keysize 2048 -validity 10000 -alias axion-track
```

Update `android/app/build.gradle` to reference the keystore (standard Flutter signing setup).

---

## Connecting to Your Traccar Server

When the app opens, enter:
- **Server URL**: `https://your-domain.com` or `http://192.168.1.x:8082`
- **Email**: your Traccar admin email
- **Password**: your password

The app saves credentials locally (SharedPreferences) and auto-logs in on next launch.

### Self-hosted server (HTTP)
The Android `network_security_config.xml` and iOS `NSAllowsArbitraryLoads` already allow HTTP connections for self-hosted servers.

### Demo server
Tap "Try the public demo?" to prefill `demo.traccar.org / demo@traccar.org / demo`.

---

## Features

| Feature | Details |
|---|---|
| **Status Page** | All vehicles with live status, sensor chips, address |
| **Filter Pills** | Filter by running/stopped/idle/offline/nodata/expired |
| **Quick Actions** | Tap vehicle → Track, History, Reports, Immobilizer, Sensors |
| **Live Map** | OpenStreetMap tiles, animated vehicle pins, bottom info sheet |
| **Live Tracking** | Full-screen map with follow mode, speedometer gauge |
| **History** | Trip/stop timeline, route polyline, animated playback scrubber |
| **Sensors** | All device attributes with icons and formatted values |
| **Alerts** | Event feed with vehicle + type filters |
| **Settings** | Profile, connection status, WebSocket indicator, sign out |
| **WebSocket** | Real-time position + event updates, auto-reconnect |
| **Auto-login** | Credentials saved, splash screen checks session |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `flutter pub get` fails | Check internet, run `flutter clean` first |
| Map tiles not loading | Check internet permission in AndroidManifest |
| HTTP server not connecting | Confirm `network_security_config.xml` is referenced in AndroidManifest |
| WebSocket not connecting | Some servers need `ws://` not `wss://` — check server SSL config |
| `JAVA_HOME` error | Install JDK 17: `https://adoptium.net` |
| Build fails on iOS | Run `cd ios && pod install` then retry |
| App crashes on launch | Run `flutter run --verbose` to see error |

---

## Dependencies Used

| Package | Purpose |
|---|---|
| `provider` | State management |
| `http` | REST API calls |
| `web_socket_channel` | WebSocket live updates |
| `flutter_map` | OpenStreetMap integration |
| `latlong2` | Coordinate types for flutter_map |
| `shared_preferences` | Persist login credentials |
| `fl_chart` | Charts in reports |
| `intl` | Date/time formatting |
| `shimmer` | Loading skeleton cards |
| `url_launcher` | Open WhatsApp/website links |

All packages are null-safe and compatible with Flutter 3.x.
