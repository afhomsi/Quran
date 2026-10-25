import 'package:flutter/material.dart';

import '../../l10n/strings.dart';

/// One source of the app's content and the terms it is used under.
typedef ContentSource = ({String Function(S) title, String detail});

/// Everything the app shows that it did not make itself. Each source is
/// open or free of copyright; their licences ask to be named here.
final contentSources = <ContentSource>[
  (
    title: (t) => t.sourceQuranText,
    detail:
        'King Fahd Glorious Quran Printing Complex, via QuranEnc.com and '
        'risan/quran-json (CC BY-SA 4.0). Seven ayat were matched to the '
        'Quran.com text.',
  ),
  (
    title: (t) => t.sourceMushaf,
    detail:
        'Page layout: Quranic Universal Library (qul.tarteel.ai), via '
        'quran_library (MIT). Font: DigitalKhatt New Madina, Amine Anane '
        'and Tarteel (SIL Open Font License 1.1). Tajweed colours: worked '
        'out by the app from the text. Interface font: IBM Plex Sans '
        'Arabic, IBM (SIL Open Font License 1.1).',
  ),
  (
    title: (t) => t.sourceTafsir,
    detail:
        "Al-Jalalayn, as-Sa'di, Ibn Kathir, al-Baghawi, at-Tabari, an-Nashr "
        "of Ibn al-Jazari and ad-Durr al-Masun of as-Samin al-Halabi: "
        'classical works in the public domain, via spa5k/tafsir_api (MIT). '
        'Al-Jalalayn is kept in the app for searching by meaning.',
  ),
  (
    title: (t) => t.sourceTranslation,
    detail:
        'The Meaning of the Glorious Koran, Marmaduke Pickthall (1930), in '
        'the public domain, via fawazahmed0/quran-api (Unlicense). Kept in '
        'the app for searching in English.',
  ),
  (
    title: (t) => t.sourceRecitations,
    detail:
        'everyayah.com (one recording per ayah). mp3quran.net (whole-surah '
        'recordings and the time of each ayah in them): Saber Abdulhakam, '
        'Bandar Baleela, Khalid Al-Muhanna.',
  ),
];

/// Lists where the app's content comes from, with the licences of the
/// software it is built with one tap away.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.sources), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final s in contentSources)
            ListTile(
              title: Text(s.title(t), style: theme.textTheme.titleMedium),
              subtitle: Text(
                s.detail,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.start,
              ),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: Text(t.softwareLicences),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(context: context),
          ),
        ],
      ),
    );
  }
}
