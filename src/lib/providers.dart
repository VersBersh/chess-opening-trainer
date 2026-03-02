import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repositories/repertoire_repository.dart';
import 'repositories/review_repository.dart';

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
// Shared preferences provider
// ---------------------------------------------------------------------------

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});
