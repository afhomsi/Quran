import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mushaf_models.dart';
import 'reading_state.dart';

const recitationHistoryKey = 'recitation_history';

/// How many recitations are kept; older ones are dropped.
const _maxRecords = 300;

/// A mistake made while reciting.
class MistakeRecord {
  const MistakeRecord(this.ayah, this.message);

  /// The ayah the mistake is in; null in the basmala or isti'adha.
  final AyahRef? ayah;
  final String message;

  Map<String, dynamic> toJson() => {'ayah': ?ayah?.toString(), 'msg': message};

  factory MistakeRecord.fromJson(Map<String, dynamic> json) => MistakeRecord(
    json['ayah'] == null ? null : AyahRef.parse(json['ayah'] as String),
    json['msg'] as String,
  );
}

/// One recitation check: what was recited and the mistakes made.
class RecitationRecord {
  const RecitationRecord({
    required this.date,
    this.surah,
    this.page,
    required this.first,
    required this.last,
    required this.wordsDone,
    required this.wordsTotal,
    required this.complete,
    required this.mistakes,
  });

  final DateTime date;

  /// The surah recited, or null when a [page] was recited.
  final int? surah;
  final int? page;

  /// The first and last ayah reached.
  final AyahRef first;
  final AyahRef last;
  final int wordsDone;
  final int wordsTotal;
  final bool complete;
  final List<MistakeRecord> mistakes;

  /// The ayat with mistakes, in reading order.
  List<AyahRef> get mistakeAyat =>
      ({for (final m in mistakes) ?m.ayah}.toList()..sort());

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'surah': ?surah,
    'page': ?page,
    'first': '$first',
    'last': '$last',
    'done': wordsDone,
    'total': wordsTotal,
    'complete': complete,
    'mistakes': [for (final m in mistakes) m.toJson()],
  };

  factory RecitationRecord.fromJson(Map<String, dynamic> json) =>
      RecitationRecord(
        date: DateTime.parse(json['date'] as String),
        surah: json['surah'] as int?,
        page: json['page'] as int?,
        first: AyahRef.parse(json['first'] as String),
        last: AyahRef.parse(json['last'] as String),
        wordsDone: json['done'] as int,
        wordsTotal: json['total'] as int,
        complete: json['complete'] as bool,
        mistakes: [
          for (final m in json['mistakes'] as List)
            MistakeRecord.fromJson(m as Map<String, dynamic>),
        ],
      );
}

/// Every recitation check, newest first.
class RecitationHistoryNotifier extends Notifier<List<RecitationRecord>> {
  @override
  List<RecitationRecord> build() {
    final raw = ref
        .watch(sharedPreferencesProvider)
        .getString(recitationHistoryKey);
    if (raw == null) return const [];
    return [
      for (final r in jsonDecode(raw) as List)
        RecitationRecord.fromJson(r as Map<String, dynamic>),
    ];
  }

  void add(RecitationRecord record) =>
      _save([record, ...state].take(_maxRecords).toList());

  void clear() => _save(const []);

  void _save(List<RecitationRecord> records) {
    state = records;
    ref
        .read(sharedPreferencesProvider)
        .setString(
          recitationHistoryKey,
          jsonEncode([for (final r in records) r.toJson()]),
        );
  }
}

final recitationHistoryProvider =
    NotifierProvider<RecitationHistoryNotifier, List<RecitationRecord>>(
      RecitationHistoryNotifier.new,
    );

/// How many mistakes were made in each ayah over all [records], most
/// first.
List<(AyahRef, int)> mistakesByAyah(List<RecitationRecord> records) {
  final counts = <AyahRef, int>{};
  for (final r in records) {
    for (final m in r.mistakes) {
      if (m.ayah case final a?) counts[a] = (counts[a] ?? 0) + 1;
    }
  }
  return [for (final e in counts.entries) (e.key, e.value)]
    ..sort((a, b) => b.$2 != a.$2 ? b.$2 - a.$2 : a.$1.compareTo(b.$1));
}
