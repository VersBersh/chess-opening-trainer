import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repositories/local/database.dart';
import 'repositories/repertoire_repository.dart';
import 'repositories/review_repository.dart';

// ---------------------------------------------------------------------------
// Database provider
// ---------------------------------------------------------------------------

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

// ---------------------------------------------------------------------------
// Repository providers
// ---------------------------------------------------------------------------

final repertoireRepositoryProvider = Provider<RepertoireRepository>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

// ---------------------------------------------------------------------------
// Clock provider
// ---------------------------------------------------------------------------

/// Clock function provider. Returns the current time.
/// Override in tests with a fixed or advancing clock.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

// ---------------------------------------------------------------------------
// Shared preferences provider
// ---------------------------------------------------------------------------

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});
