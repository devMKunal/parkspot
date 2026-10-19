# ParkSpot app (Flutter)

Android-first Flutter client. Clean architecture, BLoC, Material 3 with a playful look: indigo and sunshine yellow, Bricolage Grotesque for headings, Plus Jakarta Sans for everything else. Mockups: [ParkSpot UI](https://claude.ai/artifact/55egdy2J7GPVrnjnQefqu4).

## Run

```bash
cd app
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

`env/dev.json` points at the local API on `http://10.0.2.2:3000/v1` (the host machine as seen from the Android emulator). On the iOS simulator use `localhost`; on a physical phone use your laptop's LAN IP and add it to `android/app/src/debug/res/xml/network_security_config.xml`.

The app currently opens the **component gallery**, which shows every shared widget. Use the sun/moon button to switch themes.

## Layout

```
lib/
  main.dart, app.dart
  core/
    config/      AppConfig (flavor, API base URL from --dart-define-from-file)
    constants/   AppConstants (mirrors docs/*.md), StorageKeys
    theme/       AppColors, AppSemanticColors (ThemeExtension), AppTypography,
                 AppSpacing/AppRadius/AppSizes/AppDurations, AppTheme.light()/dark()
    extensions/  context.colors / context.text / context.semantic
    utils/       Money (paise), Formatters, Availability
    widgets/     ChunkyButton, AppTextField, ChoicePill, DurationPresetCard,
                 StatTile, AvailabilityBadge, LotMarker, TicketCard + DashedDivider,
                 CountdownRing, StatusChip, AlertBanner, BrandMark, PageDots
  dev/           ComponentGalleryPage (remove before release)
  features/      <feature>/{data,domain,presentation}  ← next: auth
```

Widgets read colours only through `Theme.of(context)`, never `AppColors` directly, so dark mode can't be skipped.

## Checks

```bash
dart format lib test
flutter analyze        # very_good_analysis
flutter test           # loads the bundled fonts first (test/flutter_test_config.dart)
```

CI runs the same three on every PR that touches `app/`.
