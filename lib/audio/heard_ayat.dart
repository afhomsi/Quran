import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mushaf_models.dart';
import 'ayah_audio.dart';

/// The ayat played since the player bar opened. While listening with the
/// text hidden, the mushaf shows only these, so each ayah appears as the
/// reciter reaches it. Cleared when the player closes.
class HeardAyat extends Notifier<Set<AyahRef>> {
  @override
  Set<AyahRef> build() {
    ref.listen(audioProvider, (_, audio) {
      final current = audio.current;
      if (!audio.visible) {
        if (state.isNotEmpty) state = const {};
      } else if (current != null && !state.contains(current)) {
        state = {...state, current};
      }
    });
    final audio = ref.read(audioProvider);
    return {if (audio.visible && audio.current != null) audio.current!};
  }
}

final heardAyatProvider = NotifierProvider<HeardAyat, Set<AyahRef>>(
  HeardAyat.new,
);
