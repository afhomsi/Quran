import 'package:flutter/material.dart';

import '../../data/quran_models.dart';

/// Placeholder reader: one ayah per row. M1 replaces this with the
/// page-accurate Madinah mushaf layout.
class SurahReaderScreen extends StatelessWidget {
  const SurahReaderScreen({super.key, required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(surah.name)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: surah.ayahCount,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${surah.ayahs[i]} ﴿${i + 1}﴾',
            textAlign: TextAlign.justify,
            style: const TextStyle(fontSize: 24, height: 2),
          ),
        ),
      ),
    );
  }
}
