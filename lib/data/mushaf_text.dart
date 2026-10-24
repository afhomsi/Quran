/// The font that draws the mushaf: DigitalKhatt New Madina, by Amine Anane
/// and Tarteel, under the SIL Open Font License (assets/fonts/madina.otf).
const mushafFont = 'Madina';

/// Marks of the KFGQPC Uthmani text that the font has at other code
/// points: the open tanween, the small high madda and the small low seen.
const _fontCodePoints = {
  0x0656: 0x08F2,
  0x0657: 0x08F0,
  0x065E: 0x08F1,
  0x06E4: 0x0653,
  0x06EA: 0x065C,
};

/// [text] with the code points the mushaf font draws. Each character stays
/// one character, so offsets into [text] still hold.
String mushafDisplayText(String text) =>
    String.fromCharCodes(text.codeUnits.map((c) => _fontCodePoints[c] ?? c));

/// The end of ayah [number]: the font draws ۝ and the digits after it as one
/// medallion.
String ayahEndMark(int number) =>
    '۝${number.toString().split('').map((d) => String.fromCharCode(0x0660 + int.parse(d))).join()}';

/// The basmala, as printed above each surah but at-Tawbah.
const basmalaText = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ';
