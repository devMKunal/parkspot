import 'package:parkspot/core/constants/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Real [SharedPreferencesWithCache] over an in-memory store. Calling it
/// again with the same [store] reads what was written, like a relaunch.
Future<SharedPreferencesWithCache> testPrefs([
  Map<String, Object> store = const {},
]) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(store);
  return await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: {
        StorageKeys.onboardingSeen,
        StorageKeys.locationRationaleSeen,
        StorageKeys.themeMode,
      },
    ),
  );
}
