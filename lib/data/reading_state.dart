import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mushaf_models.dart';

/// Overridden in `main` with the instance loaded at startup.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider'),
);

const _lastPageKey = 'last_page';
const _bookmarksKey = 'bookmarks';

/// The page the reader was last on, so the app can resume there.
class LastPageNotifier extends Notifier<int?> {
  @override
  int? build() => ref.watch(sharedPreferencesProvider).getInt(_lastPageKey);

  void set(int page) {
    state = page;
    ref.read(sharedPreferencesProvider).setInt(_lastPageKey, page);
  }
}

final lastPageProvider = NotifierProvider<LastPageNotifier, int?>(
  LastPageNotifier.new,
);

/// Bookmarked ayat, in the order they were added.
class BookmarksNotifier extends Notifier<List<AyahRef>> {
  @override
  List<AyahRef> build() => [
    for (final s
        in ref.watch(sharedPreferencesProvider).getStringList(_bookmarksKey) ??
            const <String>[])
      AyahRef.parse(s),
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
