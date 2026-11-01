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

  /// New hifz: half a page, a page or two pages a day, from a page the
  /// user picks to the end of the mushaf, each recited from memory.
  hifz,
}

/// What a new-hifz plan may take a day, in half pages.
const hifzHalfPagesChoices = [1, 2, 4];

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
    this.recite = false,
    this.startPage = 1,
    this.halfPages = 2,
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

  /// A recitation plan: each portion is recited from memory, and is
  /// ticked off once recited to its end, instead of read.
  final bool recite;

  /// For a new-hifz plan: the page it starts on, and how much to learn a
  /// day, in half pages.
  final int startPage;
  final int halfPages;

  /// Number of days a plan of [type] takes; [customDays] is used for
  /// custom plans.
  static int daysFor(
    KhatmaType type, {
    int customDays = 30,
    int startPage = 1,
    int halfPages = 2,
  }) => switch (type) {
    KhatmaType.salaf => 7,
    KhatmaType.ramadan => 30,
    // 604 pages at 10 a day.
    KhatmaType.dailyWird => 61,
    KhatmaType.custom => customDays.clamp(1, mushafPageCount),
    // Half pages are counted as two a page, for the rounding up.
    KhatmaType.hifz =>
      ((mushafPageCount - startPage + 1) * 2 / halfPages).ceil(),
  };

  /// The portions of the plan, worked out once: the mushaf redraws its
  /// pages often, e.g. on every word recited, and asks for them each time.
  List<KhatmaPortion> portions(Mushaf m) {
    if (_portions[this] case (final mushaf, final list) when mushaf == m) {
      return list;
    }
    final list = _portionsOf(m);
    _portions[this] = (m, list);
    return list;
  }

  static final _portions = Expando<(Mushaf, List<KhatmaPortion>)>();

  List<KhatmaPortion> _portionsOf(Mushaf m) => switch (type) {
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
    KhatmaType.hifz => _hifzPortions(m),
  };

  /// The portions of a new-hifz plan: [halfPages] half pages a day from
  /// [startPage]. A half page ends at the middle ayah of the page.
  List<KhatmaPortion> _hifzPortions(Mushaf m) {
    final starts = <AyahRef>[];
    for (var p = startPage; p <= mushafPageCount; p += halfPages == 4 ? 2 : 1) {
      starts.add(m.page(p).firstAyah);
      if (halfPages == 1) {
        final ayat = [
          for (final w in m.page(p).words)
            if (w.position == 1) w.ayah,
        ];
        if (ayat.length >= 2 && ayat[ayat.length ~/ 2] != starts.last) {
          starts.add(ayat[ayat.length ~/ 2]);
        }
      }
    }
    return _between(starts, (i) => i + 1);
  }

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
        recite: recite,
        startPage: startPage,
        halfPages: halfPages,
      );

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'type': type.name,
    'color': color,
    'days': days,
    'created': created.toIso8601String(),
    'done': done.toList()..sort(),
    if (recite) 'recite': true,
    if (type == KhatmaType.hifz) ...{
      'startPage': startPage,
      'halfPages': halfPages,
    },
  };

  /// Reads what [toJson] wrote. The length is kept within what the plan
  /// form allows, so an edited backup cannot ask for pages past the end of
  /// the mushaf.
  factory KhatmaPlan.fromJson(Map<String, dynamic> json) {
    final type = KhatmaType.values.byName(json['type'] as String);
    final startPage = ((json['startPage'] as int?) ?? 1).clamp(
      1,
      mushafPageCount,
    );
    final halfPages = hifzHalfPagesChoices.contains(json['halfPages'])
        ? json['halfPages'] as int
        : 2;
    return KhatmaPlan(
      id: json['id'] as String,
      title: json['title'] as String,
      type: type,
      color: json['color'] as int,
      days: daysFor(
        type,
        customDays: json['days'] as int,
        startPage: startPage,
        halfPages: halfPages,
      ),
      created: DateTime.parse(json['created'] as String),
      done: {for (final i in json['done'] as List) i as int},
      recite: json['recite'] == true || type == KhatmaType.hifz,
      startPage: startPage,
      halfPages: halfPages,
    );
  }
}

KhatmaPlan? _tryPlan(Object? json) {
  try {
    return KhatmaPlan.fromJson(json as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

/// The user's khatma plans, newest first.
class KhatmaPlansNotifier extends Notifier<List<KhatmaPlan>> {
  @override
  List<KhatmaPlan> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_plansKey);
    return readStored(raw, (json) {
      // A damaged plan is left out, not all of them. Each plan's bookmark
      // color must be one of the colors.
      return [
        for (final p in json as List)
          if (_tryPlan(p) case final plan?)
            if (plan.color >= 0 && plan.color < khatmaColors.length) plan,
      ];
    }, const []);
  }

  KhatmaPlan add({
    required KhatmaType type,
    required String title,
    required int color,
    int customDays = 30,
    bool recite = false,
    int startPage = 1,
    int halfPages = 2,
    DateTime? now,
  }) {
    final created = now ?? DateTime.now();
    final plan = KhatmaPlan(
      id: '${created.microsecondsSinceEpoch}',
      title: title,
      type: type,
      color: color,
      days: KhatmaPlan.daysFor(
        type,
        customDays: customDays,
        startPage: startPage,
        halfPages: halfPages,
      ),
      created: created,
      // New hifz is always recited from memory to be ticked off.
      recite: recite || type == KhatmaType.hifz,
      startPage: startPage,
      halfPages: halfPages,
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
