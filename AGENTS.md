# AGENTS.md

## Cursor Cloud specific instructions

### Project overview
GymLog — Flutter gym/workout tracker app using Supabase (hosted) as backend. Single Flutter project at repo root (ignore `gymlog/` subdirectory — bare template skeleton).

### Running the app
```
flutter pub get
flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0
```
Or use `flutter run -d chrome` if Chrome is available as a device.

### Lint / Analyze
```
flutter analyze
```
Pre-existing warnings exist (deprecated `withOpacity`, unused elements). The test file `test/widget_test.dart` references `MyApp` but the actual class is `GymLogApp` — this is a known pre-existing issue causing the test to fail to compile.

### Tests
```
flutter test
```
Note: the default widget test does not compile due to the `MyApp`/`GymLogApp` mismatch mentioned above.

### Build (web)
```
flutter build web
```

### Key caveats
- Flutter SDK is installed at `/opt/flutter`. PATH must include `/opt/flutter/bin`.
- Supabase credentials are hardcoded in `lib/main.dart` (hosted instance). No local Supabase setup needed.
- The app requires internet access to reach the remote Supabase API.
- Hot reload works with `r` key when running via `flutter run`.
