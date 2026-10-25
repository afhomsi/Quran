import 'dart:convert';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mushaf_models.dart';
import 'reading_state.dart';

const _markersKey = 'markers';
const _highlightsKey = 'highlights';
const _notesKey = 'notes';

/// The three place markers: where the reader stopped reading, memorizing
/// and reviewing. Each points to one ayah.
enum MarkerKind {
  reading(Color(0xFF7B0A1E)),
  hifz(Color(0xFFEF7F1A)),
  review(Color(0xFF4E8A2E));

  const MarkerKind(this.color);

  final Color color;
}

/// Where each [MarkerKind] stands, if it is set.
class MarkersNotifier extends Notifier<Map<MarkerKind, AyahRef>> {
  @override
  Map<MarkerKind, AyahRef> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_markersKey);
    return readStored(
      raw,
      // Entries that are not a marker on an ayah of the mushaf are left
      // out, so a damaged backup cannot point the app at a missing page.
      (json) => {
        for (final e in (json as Map).entries)
          ?MarkerKind.values.asNameMap()[e.key]: ?AyahRef.tryParse(e.value),
      },
      const {},
    );
  }

  void set(MarkerKind kind, AyahRef ayah) => _save({...state, kind: ayah});

  void clear(MarkerKind kind) => _save({...state}..remove(kind));

  void _save(Map<MarkerKind, AyahRef> markers) {
    state = markers;
    ref
        .read(sharedPreferencesProvider)
        .setString(
          _markersKey,
          jsonEncode({
            for (final e in markers.entries) e.key.name: '${e.value}',
          }),
        );
  }
}

final markersProvider =
    NotifierProvider<MarkersNotifier, Map<MarkerKind, AyahRef>>(
      MarkersNotifier.new,
    );

/// Colors an ayah can be highlighted with, as in a printed mushaf marked
/// with a highlighter pen.
const highlightColors = [
  Color(0xFFFFF59D), // yellow
  Color(0xFFC5E1A5), // green
  Color(0xFF90CAF9), // blue
  Color(0xFFF8BBD0), // pink
  Color(0xFFFFCC80), // orange
  Color(0xFFD1C4E9), // purple
  Color(0xFFFFB3B3), // red
  Color(0xFFB2DFDB), // turquoise
  Color(0xFFCFD8DC), // grey
  Color(0xFFE0CFC2), // brown
];

/// Highlighted ayat and the index of their color in [highlightColors], in
/// the order they were highlighted.
class HighlightsNotifier extends Notifier<Map<AyahRef, int>> {
  @override
  Map<AyahRef, int> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_highlightsKey);
    return readStored(
      raw,
      (json) => {
        for (final e in (json as Map).entries)
          if ((AyahRef.tryParse(e.key), e.value) case (
            final ayah?,
            final int color,
          ))
            ayah: color.clamp(0, highlightColors.length - 1),
      },
      const {},
    );
  }

  void set(AyahRef ayah, int color) => _save(
    {...state}
      ..remove(ayah)
      ..[ayah] = color,
  );

  void remove(AyahRef ayah) => _save({...state}..remove(ayah));

  void _save(Map<AyahRef, int> highlights) {
    state = highlights;
    ref
        .read(sharedPreferencesProvider)
        .setString(
          _highlightsKey,
          jsonEncode({for (final e in highlights.entries) '${e.key}': e.value}),
        );
  }
}

final highlightsProvider =
    NotifierProvider<HighlightsNotifier, Map<AyahRef, int>>(
      HighlightsNotifier.new,
    );

/// The longest note kept, in characters, so a huge restored backup cannot
/// slow the app down.
const maxNoteLength = 10000;

/// The reader's own notes on ayat, in the order they were written.
class NotesNotifier extends Notifier<Map<AyahRef, String>> {
  @override
  Map<AyahRef, String> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_notesKey);
    return readStored(
      raw,
      (json) => {
        for (final e in (json as Map).entries)
          if ((AyahRef.tryParse(e.key), e.value) case (
            final ayah?,
            final String text,
          ))
            ayah: text.length > maxNoteLength
                ? text.substring(0, maxNoteLength)
                : text,
      },
      const {},
    );
  }

  /// Saves [text] as the note on [ayah]; blank text deletes the note.
  void set(AyahRef ayah, String text) {
    final notes = {...state}..remove(ayah);
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      notes[ayah] = trimmed.length > maxNoteLength
          ? trimmed.substring(0, maxNoteLength)
          : trimmed;
    }
    state = notes;
    ref
        .read(sharedPreferencesProvider)
        .setString(
          _notesKey,
          jsonEncode({for (final e in notes.entries) '${e.key}': e.value}),
        );
  }
}

final notesProvider = NotifierProvider<NotesNotifier, Map<AyahRef, String>>(
  NotesNotifier.new,
);
