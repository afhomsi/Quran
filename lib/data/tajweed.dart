import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mushaf_models.dart';

const tajweedAssetPath = 'assets/mushaf/tajweed.json';

/// The tajweed rules the colour page fonts mark, with the palette slots
/// that draw them and their colours on a light and a dark page, as in the
/// Dar al-Ma'rifah tajweed mushaf.
enum TajweedRule {
  maddLazim({3}, Color(0xFFB50000), Color(0xFFE30000)),
  maddWajib({9}, Color(0xFFF40000), Color(0xFFFF5E8E)),
  maddJaiz({4}, Color(0xFFFF7B00), Color(0xFFFF8E3B)),
  maddTabii({5}, Color(0xFFCE9E00), Color(0xFFFFC1E0)),
  ghunna({6}, Color(0xFF09B000), Color(0xFF26B55D)),
  tafkhim({7}, Color(0xFF3F48E6), Color(0xFF3C84D5)),
  qalqala({8}, Color(0xFF2FADFF), Color(0xFF00DEFF)),
  silent({1, 2, 15}, Color(0xFFA5A5A5), Color(0xFF9D9999));

  const TajweedRule(this.slots, this.light, this.dark);

  final Set<int> slots;
  final Color light;
  final Color dark;

  Color color(bool darkPage) => darkPage ? dark : light;

  static TajweedRule? ofSlot(int slot) =>
      values.where((r) => r.slots.contains(slot)).firstOrNull;
}

/// The tajweed rules on each word, read from the page fonts by
/// tool/build_tajweed_data.py.
class TajweedMap {
  TajweedMap(this._data);

  /// [surah][ayah] -> list of [position, slot, ...].
  final List<dynamic> _data;

  /// The rules on each word of [ayah] that has any, by word position.
  Map<int, Set<TajweedRule>> ofAyah(AyahRef ayah) => {
    for (final w in _data[ayah.surah - 1][ayah.ayah - 1] as List)
      (w as List).first as int: {
        for (final slot in w.skip(1)) ?TajweedRule.ofSlot(slot as int),
      },
  };
}

TajweedMap parseTajweed(String raw) => TajweedMap(jsonDecode(raw) as List);

final tajweedProvider = FutureProvider<TajweedMap>(
  (ref) async => parseTajweed(await rootBundle.loadString(tajweedAssetPath)),
);
