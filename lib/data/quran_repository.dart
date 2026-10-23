import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quran_models.dart';

const quranAssetPath = 'assets/quran/hafs_uthmani.json';

/// Loads the bundled Hafs (Uthmani) text. Works fully offline.
class QuranRepository {
  QuranRepository(this._bundle);

  final AssetBundle _bundle;

  Future<List<Surah>> loadSurahs() async {
    final raw = await _bundle.loadString(quranAssetPath);
    return parseSurahs(raw);
  }
}

List<Surah> parseSurahs(String raw) => (jsonDecode(raw) as List)
    .map((e) => Surah.fromJson(e as Map<String, dynamic>))
    .toList(growable: false);

final quranRepositoryProvider = Provider<QuranRepository>(
  (ref) => QuranRepository(rootBundle),
);

final surahsProvider = FutureProvider<List<Surah>>(
  (ref) => ref.watch(quranRepositoryProvider).loadSurahs(),
);
