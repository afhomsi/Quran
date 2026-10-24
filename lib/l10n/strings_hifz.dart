part of 'strings.dart';

/// Texts of repeating a group of ayat and of the hifz profile.
extension HifzStrings on S {
  // Repeating a group of ayat.
  String get repeatAyat =>
      _('تكرار آيات', 'Repeat ayat', 'আয়াত পুনরাবৃত্তি', 'آیات دہرائیں');
  String get repeatTitle => _(
    'تكرار مجموعة آيات',
    'Repeat a group of ayat',
    'আয়াতের দল পুনরাবৃত্তি',
    'آیات کا مجموعہ دہرائیں',
  );
  String get repeatFromHere => _(
    'كرر آيات من هنا',
    'Repeat ayat from here',
    'এখান থেকে আয়াত পুনরাবৃত্তি',
    'یہاں سے آیات دہرائیں',
  );
  String get rangeFrom => _('من', 'From', 'থেকে', 'سے');
  String get rangeTo => _('إلى', 'To', 'পর্যন্ত', 'تک');
  String ayahNumber(int ayah) => _(
    'آية ${n(ayah)}',
    'Ayah ${n(ayah)}',
    'আয়াত ${n(ayah)}',
    'آیت ${n(ayah)}',
  );
  String repeatGroup(int times) => _(
    'تكرار المجموعة كلها: ${n(times)} ${times == 1 ? 'مرة' : 'مرات'}',
    'Play the whole group: ${n(times)} ${times == 1 ? 'time' : 'times'}',
    'পুরো দল: ${n(times)} বার',
    'پورا مجموعہ: ${n(times)} بار',
  );
  String get startListening =>
      _('ابدأ الاستماع', 'Start listening', 'শোনা শুরু করুন', 'سننا شروع کریں');
  String playlistRound(int pass, int total) => _(
    'التكرار ${n(pass)} من ${n(total)}',
    'Round ${n(pass)} of ${n(total)}',
    '${n(total)} বারের ${n(pass)}',
    '${n(total)} میں سے ${n(pass)} بار',
  );
  String get listenToRecited => _(
    'استمع لهذه الآيات',
    'Listen to these ayat',
    'এই আয়াতগুলো শুনুন',
    'یہ آیات سنیں',
  );
  String get listenToMistakes => _(
    'استمع للآيات التي أخطأت فيها',
    'Listen to the ayat with mistakes',
    'ভুল হওয়া আয়াতগুলো শুনুন',
    'غلطی والی آیات سنیں',
  );

  // Hifz profile.
  String get myProfile =>
      _('ملفي', 'My profile', 'আমার প্রোফাইল', 'میری پروفائل');
  String get profileTitle => _(
    'ملفي في الحفظ',
    'My hifz profile',
    'আমার হিফজ প্রোফাইল',
    'میری حفظ پروفائل',
  );
  String get recitationsLabel =>
      _('مرات التسميع', 'Recitations', 'তিলাওয়াত', 'تسمیع');
  String get withoutMistakes =>
      _('بلا أخطاء', 'No mistakes', 'ভুল ছাড়া', 'بغیر غلطی');
  String get mistakesLabel => _('الأخطاء', 'Mistakes', 'ভুল', 'غلطیاں');
  String get ayatWithMistakes => _(
    'الآيات التي أخطأت فيها',
    'Ayat with mistakes',
    'যে আয়াতে ভুল হয়েছে',
    'جن آیات میں غلطی ہوئی',
  );
  String mistakeTimes(int times) => _(
    'أخطأت فيها ${n(times)} ${times == 1 ? 'مرة' : 'مرات'}',
    '${n(times)} ${times == 1 ? 'mistake' : 'mistakes'}',
    '${n(times)} বার ভুল',
    '${n(times)} بار غلطی',
  );
  String mistakesCount(int count) => _(
    '${n(count)} ${count == 1 ? 'خطأ' : 'أخطاء'}',
    '${n(count)} ${count == 1 ? 'mistake' : 'mistakes'}',
    '${n(count)}টি ভুল',
    '${n(count)} غلطیاں',
  );
  String get listenToAll => _(
    'استمع لها كلها مع التكرار',
    'Listen to all, with repeats',
    'সবগুলো পুনরাবৃত্তিসহ শুনুন',
    'سب کو دہرائی کے ساتھ سنیں',
  );
  String get historyTitle => _(
    'سجل التسميع',
    'Recitation history',
    'তিলাওয়াতের ইতিহাস',
    'تسمیع کی تاریخ',
  );
  String get noHistory => _(
    'لم تسمّع شيئًا بعد. اضغط «تسميع» في المصحف لتبدأ.',
    'Nothing recited yet. Press "Recite" in the mushaf to start.',
    'এখনও কিছু তিলাওয়াত করেননি। শুরু করতে মুসহাফে "তিলাওয়াত যাচাই" চাপুন।',
    'ابھی کوئی تسمیع نہیں ہوئی۔ شروع کرنے کے لیے مصحف میں «تسمیع» دبائیں۔',
  );
  String recitedRange(String from, String to) => _(
    'سمّعت من $from إلى $to',
    'Recited from $from to $to',
    '$from থেকে $to পর্যন্ত তিলাওয়াত',
    '$from سے $to تک تسمیع',
  );
  String wordsDone(int done, int total) => _(
    '${n(done)} من ${n(total)} كلمة',
    '${n(done)} of ${n(total)} words',
    '${n(total)} শব্দের মধ্যে ${n(done)}',
    '${n(total)} میں سے ${n(done)} الفاظ',
  );
  String get notFinished =>
      _('لم يكتمل', 'Not finished', 'অসম্পূর্ণ', 'نامکمل');
  String get clearHistory =>
      _('مسح السجل', 'Clear history', 'ইতিহাস মুছুন', 'تاریخ مٹائیں');
  String get clearHistoryQuestion => _(
    'هل تريد مسح سجل التسميع كله؟',
    'Clear the whole recitation history?',
    'পুরো তিলাওয়াতের ইতিহাস মুছবেন?',
    'کیا پوری تسمیع کی تاریخ مٹا دیں؟',
  );
  String date(DateTime d) =>
      '${n(d.year)}/${n(d.month)}/${n(d.day)} · ${clock(d.hour, d.minute)}';
}
