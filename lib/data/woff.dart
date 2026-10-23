import 'dart:typed_data';

import 'package:archive/archive.dart' show ZLibDecoder;

/// Converts a WOFF 1.0 font to the plain TrueType/OpenType (sfnt) bytes that
/// [FontLoader] accepts on every platform.
///
/// Spec: https://www.w3.org/TR/WOFF/
Uint8List woffToSfnt(Uint8List woff) {
  final src = ByteData.sublistView(woff);
  if (src.getUint32(0) != 0x774F4646) {
    throw const FormatException('Not a WOFF font');
  }
  final flavor = src.getUint32(4);
  final numTables = src.getUint16(12);

  final tables = <({int tag, int checksum, Uint8List data})>[];
  // Pure Dart zlib, so this also runs on the web, where dart:io is missing.
  final zlib = ZLibDecoder();
  for (var i = 0; i < numTables; i++) {
    final entry = 44 + i * 20;
    final offset = src.getUint32(entry + 4);
    final compLength = src.getUint32(entry + 8);
    final origLength = src.getUint32(entry + 12);
    final raw = Uint8List.sublistView(woff, offset, offset + compLength);
    tables.add((
      tag: src.getUint32(entry),
      checksum: src.getUint32(entry + 16),
      data: compLength < origLength
          ? Uint8List.fromList(zlib.decodeBytes(raw))
          : raw,
    ));
  }

  var searchRange = 1, entrySelector = 0;
  while (searchRange * 2 <= numTables) {
    searchRange *= 2;
    entrySelector++;
  }
  searchRange *= 16;

  final headerSize = 12 + numTables * 16;
  final size = tables.fold<int>(headerSize, (n, t) => n + _pad4(t.data.length));
  final out = Uint8List(size);
  final dst = ByteData.sublistView(out)
    ..setUint32(0, flavor)
    ..setUint16(4, numTables)
    ..setUint16(6, searchRange)
    ..setUint16(8, entrySelector)
    ..setUint16(10, numTables * 16 - searchRange);

  var offset = headerSize;
  for (var i = 0; i < tables.length; i++) {
    final t = tables[i];
    final record = 12 + i * 16;
    dst
      ..setUint32(record, t.tag)
      ..setUint32(record + 4, t.checksum)
      ..setUint32(record + 8, offset)
      ..setUint32(record + 12, t.data.length);
    out.setRange(offset, offset + t.data.length, t.data);
    offset += _pad4(t.data.length);
  }
  return out;
}

int _pad4(int n) => (n + 3) & ~3;
