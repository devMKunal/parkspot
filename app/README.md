# ParkSpot app (Flutter)

Android-first Flutter client. Clean architecture, BLoC, Material 3 with a playful look: indigo and sunshine yellow, Bricolage Grotesque for headings, Plus Jakarta Sans for everything else. Mockups: [ParkSpot UI](https://claude.ai/artifact/55egdy2J7GPVrnjnQefqu4).

## Run

```bash
cd app
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

### Google Maps keys

The map needs a Google Maps key per platform. In [Google Cloud](https://console.cloud.google.com), link billing to a project (map loads in the mobile SDKs are free) and enable **Maps SDK for Android** and **Maps SDK for iOS**. Then, under **APIs & Services → Credentials**, create two API keys:

| Key | Application restriction | API restriction |
| --- | --- | --- |
| Android | Android apps: `com.devmkunal.parkspot` + your debug SHA-1 | Maps SDK for Android |
| iOS | iOS apps: `com.devmkunal.parkspot` | Maps SDK for iOS |

Your debug SHA-1 (each Mac has its own; release builds need the release or Play App Signing SHA-1 too):

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android | grep SHA1
```

Put the keys in these git-ignored files:

- Android: `MAPS_API_KEY=...` in `android/local.properties`
- iOS: `MAPS_API_KEY = ...` in `ios/Flutter/Secrets.xcconfig`

Stop the app and run it again after adding a key; hot restart doesn't pick it up (on iOS, `flutter clean` first). A new key can take a few minutes to start working. Without a key the app still runs, but the map is blank (iOS logs a warning at launch).

### API and lots

The seeded lots are in Pune (`cd ../api && npm run seed`), and the map searches around you, so put the emulator or simulator there:

- Android emulator: **⋯ → Location**, or `adb emu geo fix 73.8567 18.5204` (longitude first). Its default is Mountain View.
- iOS simulator: `xcrun simctl location booted set 18.5204,73.8567`

Start the API first (`cd ../api && npm run dev`, port 3000). The app picks the host for the device it runs on:

| Device | API base URL |
| --- | --- |
| Android emulator | `http://10.0.2.2:3000/v1` (the emulator's `localhost` is itself) |
| iOS simulator | `http://localhost:3000/v1` |
| Physical phone, same Wi-Fi | `http://<Mac LAN IP>:3000/v1` |

For a physical phone, pass the Mac's IP:

```bash
flutter run --dart-define-from-file=env/dev.json --dart-define=LAN_HOST=$(ipconfig getifaddr en0)
```

Another port: `--dart-define=API_PORT=4000`. `API_BASE_URL` overrides all of it (`env/prod.json` sets it).

The splash restores the session against the API. Dev builds also have the **component gallery** at `/dev/gallery`.

## Layout

```
lib/
  main.dart, app.dart
  core/
    config/      AppConfig (flavor, API base URL from --dart-define-from-file)
    di/          injector.dart: the get_it composition root, called from main
    network/     dio setup, AuthInterceptor (refresh on TOKEN_EXPIRED, single-flight),
                 ApiException (the {error:{code,message}} envelope; repositories throw only this)
    storage/     TokenStore: refresh token in secure storage, access token in memory
    constants/   AppConstants (mirrors docs/*.md), StorageKeys
    theme/       AppColors, AppSemanticColors (ThemeExtension), AppTypography,
                 AppSpacing/AppRadius/AppSizes/AppDurations, AppTheme.light()/dark()
    extensions/  context.colors / context.text / context.semantic
    utils/       Money (paise), Formatters, Availability
    widgets/     ChunkyButton, AppTextField, ChoicePill, DurationPresetCard,
                 StatTile, AvailabilityBadge, LotMarker, TicketCard + DashedDivider,
                 CountdownRing, StatusChip, AlertBanner, BrandMark, PageDots
  dev/           ComponentGalleryPage (remove before release)
  features/      <feature>/{data,domain,presentation}
                 presentation/ holds bloc/ and screen/. A page provides its bloc
                 from get_it and wraps a View that tests pump with a mock bloc.
```

Widgets read colours only through `Theme.of(context)`, never `AppColors` directly, so dark mode can't be skipped.

## Checks

```bash
dart format lib test
flutter analyze        # very_good_analysis
flutter test           # loads the bundled fonts first (test/flutter_test_config.dart)
```

CI runs the same three on every PR that touches `app/`.
