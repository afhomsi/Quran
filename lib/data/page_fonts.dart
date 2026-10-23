import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'woff.dart';

/// Loads the QCF font of each mushaf page on first use. Every page has its
/// own font, and the word glyphs only make sense in that page's font.
class PageFonts {
  PageFonts(this._bundle);

  final AssetBundle _bundle;
  final _loading = <int, Future<String>>{};
  final _ready = <int, Future<void>>{};

  static String familyFor(int page) =>
      'QCF_P${page.toString().padLeft(3, '0')}';

  /// Returns the font family for [page] once it is ready to draw.
  Future<String> load(int page) => _loading[page] ??= _load(page);

  /// Completes once [page] can be drawn: its own font plus the page 1 font,
  /// which draws the basmala. Returns the same future on every call, so a
  /// [FutureBuilder] does not restart.
  Future<void> ready(int page) =>
      _ready[page] ??= Future.wait([load(page), load(1)]);

  Future<String> _load(int page) async {
    final family = familyFor(page);
    final path = 'assets/mushaf/fonts/p${page.toString().padLeft(3, '0')}.woff';
    final woff = await _bundle.load(path);
    final ttf = woffToSfnt(
      woff.buffer.asUint8List(woff.offsetInBytes, woff.lengthInBytes),
    );
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(ttf)));
    await loader.load();
    return family;
  }
}

final pageFontsProvider = Provider<PageFonts>((ref) => PageFonts(rootBundle));
