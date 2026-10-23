import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/data/mushaf_models.dart';
import 'package:hifz/data/reading_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('remembers the last page across restarts', () async {
    final first = await _container();
    expect(first.read(lastPageProvider), isNull);
    first.read(lastPageProvider.notifier).set(42);

    final second = await _container();
    expect(second.read(lastPageProvider), 42);
  });

  test('adds and removes bookmarks and keeps them', () async {
    const kursi = AyahRef(2, 255);
    const kahf = AyahRef(18, 1);
    final first = await _container();
    final notifier = first.read(bookmarksProvider.notifier);
    notifier.toggle(kursi);
    notifier.toggle(kahf);
    notifier.toggle(kursi);
    expect(first.read(bookmarksProvider), [kahf]);

    final second = await _container();
    expect(second.read(bookmarksProvider), [kahf]);
  });
}
