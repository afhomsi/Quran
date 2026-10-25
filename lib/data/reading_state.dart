import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mushaf_models.dart';
import 'mushaf_repository.dart' show mushafPageCount;

/// Overridden in `main` with the instance loaded at startup.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider'),
);

/// Reads data saved as JSON with [parse]. Gives [fallback] when nothing is
/// saved, or when the saved data cannot be read, e.g. after restoring a
/// damaged backup, so the app still opens.
T readStored<T>(String? raw, T Function(Object? json) parse, T fallback) {
  if (raw == null) return fallback;
  try {
    return parse(jsonDecode(raw));
  } catch (_) {
    return fallback;
  }
}

const _lastPageKey = 'last_page';
const _bookmarksKey = 'bookmarks';

/// The page the reader was last on, so the app can resume there.
class LastPageNotifier extends Notifier<int?> {
  @override
  int? build() {
    final page = ref.watch(sharedPreferencesProvider).getInt(_lastPageKey);
    // A page outside the mushaf, e.g. from an edited backup, is ignored.
    return page != null && page >= 1 && page <= mushafPageCount ? page : null;
  }

  void set(int page) {
    state = page;
    ref.read(sharedPreferencesProvider).setInt(_lastPageKey, page);
  }
}

final lastPageProvider = NotifierProvider<LastPageNotifier, int?>(
  LastPageNotifier.new,
);

const _lastRecitationKey = 'last_recitation';

/// The ayah to go on reciting from: where the reciter last stopped in the
/// mushaf, so the app can resume there like it resumes reading.
class LastRecitationNotifier extends Notifier<AyahRef?> {
  @override
  AyahRef? build() => readStored(
    ref.watch(sharedPreferencesProvider).getString(_lastRecitationKey),
    (json) {
      final map = json! as Map<String, dynamic>;
      final ayah = AyahRef(map['surah'] as int, map['ayah'] as int);
      return ayah.isValid ? ayah : null;
    },
    null,
  );

  void set(AyahRef? ayah) {
    if (ayah == state) return;
    state = ayah;
    final prefs = ref.read(sharedPreferencesProvider);
    if (ayah == null) {
      prefs.remove(_lastRecitationKey);
    } else {
      prefs.setString(
        _lastRecitationKey,
        jsonEncode({'surah': ayah.surah, 'ayah': ayah.ayah}),
      );
    }
  }
}

final lastRecitationProvider =
    NotifierProvider<LastRecitationNotifier, AyahRef?>(
      LastRecitationNotifier.new,
    );

/// Bookmarked ayat, in the order they were added.
class BookmarksNotifier extends Notifier<List<AyahRef>> {
  @override
  List<AyahRef> build() => [
    for (final s
        in ref.watch(sharedPreferencesProvider).getStringList(_bookmarksKey) ??
            const <String>[])
      ?AyahRef.tryParse(s),
  ];

  bool contains(AyahRef ayah) => state.contains(ayah);

  void toggle(AyahRef ayah) {
    state = contains(ayah)
        ? [
            for (final b in state)
              if (b != ayah) b,
          ]
        : [...state, ayah];
    ref.read(sharedPreferencesProvider).setStringList(_bookmarksKey, [
      for (final b in state) '$b',
    ]);
  }
}

final bookmarksProvider = NotifierProvider<BookmarksNotifier, List<AyahRef>>(
  BookmarksNotifier.new,
);
