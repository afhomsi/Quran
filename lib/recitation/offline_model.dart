import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_speech.dart';

enum OfflineModelStatus {
  /// This platform recognizes speech another way (the web).
  unsupported,
  checking,
  missing,
  downloading,
  ready,
}

class OfflineModelState {
  const OfflineModelState(
    this.status, {
    this.received = 0,
    this.total = 0,
    this.error,
  });

  final OfflineModelStatus status;
  final int received;
  final int total;

  /// Why the last download failed.
  final String? error;

  double? get progress => total > 0 ? received / total : null;
}

/// Whether the offline recitation model is on the device, and downloads it.
class OfflineModelNotifier extends Notifier<OfflineModelState> {
  @override
  OfflineModelState build() {
    if (!offlineSpeechSupported) {
      return const OfflineModelState(OfflineModelStatus.unsupported);
    }
    _check();
    return const OfflineModelState(OfflineModelStatus.checking);
  }

  Future<void> _check() async {
    final installed = await isOfflineModelInstalled();
    state = OfflineModelState(
      installed ? OfflineModelStatus.ready : OfflineModelStatus.missing,
    );
  }

  Future<void> download() async {
    if (state.status == OfflineModelStatus.downloading) return;
    state = const OfflineModelState(OfflineModelStatus.downloading);
    try {
      await downloadOfflineModel((received, total) {
        state = OfflineModelState(
          OfflineModelStatus.downloading,
          received: received,
          total: total,
        );
      });
      state = const OfflineModelState(OfflineModelStatus.ready);
    } catch (e) {
      state = OfflineModelState(
        OfflineModelStatus.missing,
        error: 'تعذر تحميل نموذج التلاوة. تأكد من الاتصال بالإنترنت ثم حاول مرة أخرى.',
      );
    }
  }

  Future<void> delete() async {
    await deleteOfflineModel();
    state = const OfflineModelState(OfflineModelStatus.missing);
  }
}

final offlineModelProvider =
    NotifierProvider<OfflineModelNotifier, OfflineModelState>(
      OfflineModelNotifier.new,
    );
