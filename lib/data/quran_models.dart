class Surah {
  const Surah({
    required this.number,
    required this.name,
    required this.transliteration,
    required this.isMeccan,
    required this.ayahs,
  });

  final int number;
  final String name;
  final String transliteration;
  final bool isMeccan;
  final List<String> ayahs;

  int get ayahCount => ayahs.length;

  factory Surah.fromJson(Map<String, dynamic> json) => Surah(
    number: json['id'] as int,
    name: json['name'] as String,
    transliteration: json['translit'] as String,
    isMeccan: json['type'] == 'meccan',
    ayahs: List<String>.from(json['ayahs'] as List),
  );
}
