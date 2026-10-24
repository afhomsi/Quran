import 'dart:convert';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mushaf_models.dart';
import 'mushaf_repository.dart';
import 'reading_state.dart';

const _plansKey = 'khatma_plans';

/// The kinds of khatma plan the user can start.
enum KhatmaType {
  /// Hizb of the Salaf: the whole Quran in 7 days, one manzil a day.
  salaf,

  /// One juz a day, the whole Quran in 30 days.
  ramadan,

  /// Two pages after each of the five prayers, 10 pages a day.
  dailyWird,

  /// The whole Quran in a number of days the user picks.
  custom,
}

/// Colors of the plan's bookmark, from the plan form.
const khatmaColors = [
  Color(0xFF12897A), // teal
  Color(0xFF7B4FD6), // violet
  Color(0xFF2F72D9), // blue
  Color(0xFFC98A12), // amber
  Color(0xFFD9534F), // coral
];

/// First ayah of each of the 7 manzils of the hizb of the Salaf (فمي
/// بشوق): al-Fatiha, al-Ma'ida, Yunus, al-Isra, ash-Shu'ara, as-Saffat
/// and Qaf.
const salafManzilStarts = [
  AyahRef(1, 1),
  AyahRef(5, 1),
  AyahRef(10, 1),
  AyahRef(17, 1),
  AyahRef(26, 1),
  AyahRef(37, 1),
  AyahRef(50, 1),
];

/// One part of a plan: read from [from] up to, but not including, [until]
/// (the end of the Quran when null), on [day] of the plan.
class KhatmaPortion {
  const KhatmaPortion({
    required this.day,
    required this.from,
    required this.until,
    this.prayer,
  });

  final int day;
  final AyahRef from;
  final AyahRef? until;

  /// 0 to 4, Fajr to Isha, for the daily wird, which has one portion
  /// after each prayer.
  final int? prayer;

  int firstPage(Mushaf m) => m.pageOf(from);

  /// The page of the last ayah of the portion.
  int lastPage(Mushaf m) {
    if (until == null) return mushafPageCount;
    final p = m.pageOf(until!);
    return m.page(p).firstAyah == until ? p - 1 : p;
  }
}

class KhatmaPlan {
  const KhatmaPlan({
    required this.id,
    required this.title,
    required this.type,
    required this.color,
    required this.days,
    required this.created,
    this.done = const {},
  });

  final String id;
  final String title;
  final KhatmaType type;

  /// Index in [khatmaColors].
  final int color;

  /// Length of the plan in days.
  final int days;
  final DateTime created;

  /// Indexes of the portions read so far.
  final Set<int> done;

  /// Number of days a plan of [type] takes; [customDays] is used for
  /// custom plans.
  static int daysFor(KhatmaType type, {int customDays = 30}) => switch (type) {
    KhatmaType.salaf => 7,
    KhatmaType.ramadan => 30,
    // 604 pages at 10 a day.
    KhatmaType.dailyWird => 61,
    KhatmaType.custom => customDays.clamp(1, mushafPageCount),
  };

  List<KhatmaPortion> portions(Mushaf m) => switch (type) {
    KhatmaType.salaf => _between(salafManzilStarts, (i) => i + 1),
    KhatmaType.ramadan => _between(juzStarts, (i) => i + 1),
    KhatmaType.dailyWird => [
      for (var i = 0; i * 2 < mushafPageCount; i++)
        KhatmaPortion(
          day: i ~/ 5 + 1,
          prayer: i % 5,
          from: m.page(i * 2 + 1).firstAyah,
          until: i * 2 + 3 > mushafPageCount
              ? null
              : m.page(i * 2 + 3).firstAyah,
        ),
    ],
    KhatmaType.custom => [
      for (var d = 0; d < days; d++)
        KhatmaPortion(
          day: d + 1,
          from: m.page(_customStart(d)).firstAyah,
          until: d + 1 == days ? null : m.page(_customStart(d + 1)).firstAyah,
        ),
    ],
  };

  int _customStart(int day) => (day * mushafPageCount / days).round() + 1;

  List<KhatmaPortion> _between(List<AyahRef> starts, int Function(int) day) => [
    for (var i = 0; i < starts.length; i++)
      KhatmaPortion(
        day: day(i),
        from: starts[i],
        until: i + 1 < starts.length ? starts[i + 1] : null,
      ),
  ];

  /// The first portion not read yet, or null when the khatma is complete.
  int? nextPortion(Mushaf m) {
    final count = portions(m).length;
    for (var i = 0; i < count; i++) {
      if (!done.contains(i)) return i;
    }
    return null;
  }

  /// Day of the plan that [now] falls on, starting at 1.
  int dayOn(DateTime now) {
    final start = DateTime(created.year, created.month, created.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(start).inDays + 1;
  }

  KhatmaPlan copyWith({String? title, int? color, Set<int>? done}) =>
      KhatmaPlan(
        id: id,
        title: title ?? this.title,
        type: type,
        color: color ?? this.color,
        days: days,
        created: created,
        done: done ?? this.done,
      );

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'type': type.name,
    'color': color,
    'days': days,
    'created': created.toIso8601String(),
    'done': done.toList()..sort(),
  };

  factory KhatmaPlan.fromJson(Map<String, dynamic> json) => KhatmaPlan(
    id: json['id'] as String,
    title: json['title'] as String,
    type: KhatmaType.values.byName(json['type'] as String),
    color: json['color'] as int,
    days: json['days'] as int,
    created: DateTime.parse(json['created'] as String),
    done: {for (final i in json['done'] as List) i as int},
  );
}

/// The user's khatma plans, newest first.
class KhatmaPlansNotifier extends Notifier<List<KhatmaPlan>> {
  @override
  List<KhatmaPlan> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_plansKey);
    return readStored(raw, (json) {
      final plans = [
        for (final p in json as List)
          KhatmaPlan.fromJson(p as Map<String, dynamic>),
      ];
      // Each plan's bookmark color must be one of the colors.
      for (final p in plans) {
        RangeError.checkValueInInterval(p.color, 0, khatmaColors.length - 1);
      }
      return plans;
    }, const []);
  }

  KhatmaPlan add({
    required KhatmaType type,
    required String title,
    required int color,
    int customDays = 30,
    DateTime? now,
  }) {
    final created = now ?? DateTime.now();
    final plan = KhatmaPlan(
      id: '${created.microsecondsSinceEpoch}',
      title: title,
      type: type,
      color: color,
      days: KhatmaPlan.daysFor(type, customDays: customDays),
      created: created,
    );
    _save([plan, ...state]);
    return plan;
  }

  void remove(String id) => _save([
    for (final p in state)
      if (p.id != id) p,
  ]);

  /// Marks portion [index] of plan [id] as read, or unread when [read] is
  /// false.
  void setRead(String id, int index, {bool read = true}) => _save([
    for (final p in state)
      if (p.id != id)
        p
      else
        p.copyWith(
          done: read ? {...p.done, index} : ({...p.done}..remove(index)),
        ),
  ]);

  void _save(List<KhatmaPlan> plans) {
    state = plans;
    ref
        .read(sharedPreferencesProvider)
        .setString(_plansKey, jsonEncode([for (final p in plans) p.toJson()]));
  }
}

final khatmaPlansProvider =
    NotifierProvider<KhatmaPlansNotifier, List<KhatmaPlan>>(
      KhatmaPlansNotifier.new,
    );
