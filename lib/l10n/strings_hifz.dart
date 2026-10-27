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

  // Reciting in the mushaf page.
  String get closeRecitation => _(
    'إغلاق التسميع',
    'Close reciting',
    'তিলাওয়াত বন্ধ করুন',
    'تسمیع بند کریں',
  );
  String get pressMicToRecite => _(
    'اضغط الميكروفون ثم اقرأ الصفحة من حفظك.',
    'Press the microphone, then recite the page from memory.',
    'মাইক্রোফোন চাপুন, তারপর মুখস্থ থেকে পৃষ্ঠাটি পড়ুন।',
    'مائیکروفون دبائیں، پھر صفحہ زبانی پڑھیں۔',
  );
  // Reciting from anywhere: the app finds the place.
  String get autoRecite => _(
    'تسميع تلقائي: اقرأ من أي موضع',
    'Auto recite: start anywhere',
    'স্বয়ংক্রিয় তিলাওয়াত: যেকোনো জায়গা থেকে পড়ুন',
    'خودکار تسمیع: کہیں سے بھی پڑھیں',
  );
  String get autoReciteHelp => _(
    'لا تختر سورة ولا صفحة: ابدأ القراءة ولو من وسط السورة، فيعرف التطبيق موضعك ويفتح الصفحة ويتابعك.',
    'No need to choose a surah or page: start reciting, even mid-surah, and the app finds the place, opens the page and follows you.',
    'সূরা বা পৃষ্ঠা বাছতে হবে না: সূরার মাঝখান থেকেও পড়া শুরু করুন, অ্যাপ জায়গাটি খুঁজে পৃষ্ঠা খুলে আপনাকে অনুসরণ করবে।',
    'سورت یا صفحہ چننے کی ضرورت نہیں: سورت کے درمیان سے بھی پڑھنا شروع کریں، ایپ جگہ ڈھونڈ کر صفحہ کھولے گی اور ساتھ چلے گی۔',
  );
  String get autoReciteSearching => _(
    'ابدأ القراءة من أي موضع… أبحث عن موضعك في القرآن',
    'Start reciting anywhere… finding your place in the Quran',
    'যেকোনো জায়গা থেকে পড়া শুরু করুন… কুরআনে আপনার জায়গা খুঁজছি',
    'کہیں سے بھی پڑھنا شروع کریں… قرآن میں آپ کی جگہ ڈھونڈ رہا ہوں',
  );
  String get autoReciteKeepGoing => _(
    'تابع القراءة، أحتاج كلمات أكثر لأعرف الموضع',
    'Keep reciting; a few more words are needed to find the place',
    'পড়তে থাকুন; জায়গা খুঁজতে আরও কিছু শব্দ দরকার',
    'پڑھتے رہیں؛ جگہ ڈھونڈنے کے لیے کچھ اور الفاظ چاہییں',
  );
  String get autoRecitePaused => _(
    'اضغط الميكروفون ثم اقرأ من أي موضع.',
    'Press the microphone, then recite from anywhere.',
    'মাইক্রোফোন চাপুন, তারপর যেকোনো জায়গা থেকে পড়ুন।',
    'مائیکروفون دبائیں، پھر کہیں سے بھی پڑھیں۔',
  );
  // Reciting without internet.
  String get offlineRecitation => _(
    'التسميع بدون إنترنت',
    'Recite without internet',
    'ইন্টারনেট ছাড়া তিলাওয়াত যাচাই',
    'بغیر انٹرنیٹ تسمیع',
  );
  String offlineRecitationNote(int bytes) => _(
    'حمّل نموذج التلاوة مرة واحدة (${megabytes(bytes)})، ثم يعمل التسميع على هاتفك بدون إنترنت.',
    'Download the recitation model once (${megabytes(bytes)}), then reciting works on your phone without internet.',
    'তিলাওয়াত মডেল একবার ডাউনলোড করুন (${megabytes(bytes)}), তারপর ইন্টারনেট ছাড়াই ফোনে তিলাওয়াত যাচাই চলবে।',
    'تلاوت کا ماڈل ایک بار ڈاؤن لوڈ کریں (${megabytes(bytes)})، پھر تسمیع آپ کے فون پر بغیر انٹرنیٹ چلے گی۔',
  );
  String offlineRecitationDownloading(int percent) => _(
    'جارٍ تحميل نموذج التلاوة… ${n(percent)}٪ أبقِ التطبيق مفتوحاً.',
    'Downloading the recitation model… ${n(percent)}%. Keep the app open.',
    'তিলাওয়াত মডেল ডাউনলোড হচ্ছে… ${n(percent)}%। অ্যাপ খোলা রাখুন।',
    'تلاوت کا ماڈل ڈاؤن لوڈ ہو رہا ہے… ${n(percent)}٪۔ ایپ کھلی رکھیں۔',
  );
  String get offlineRecitationReady => _(
    'النموذج محمّل: التسميع يعمل بدون إنترنت.',
    'Model downloaded: reciting works without internet.',
    'মডেল ডাউনলোড হয়েছে: ইন্টারনেট ছাড়াই তিলাওয়াত যাচাই চলে।',
    'ماڈل ڈاؤن لوڈ ہو گیا: تسمیع بغیر انٹرنیٹ چلتی ہے۔',
  );
  String get offlineRecitationFailed => _(
    'تعذر تحميل نموذج التلاوة. تأكد من الاتصال بالإنترنت ثم حاول مرة أخرى.',
    'Could not download the recitation model. Check the internet connection and try again.',
    'তিলাওয়াত মডেল ডাউনলোড করা যায়নি। ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।',
    'تلاوت کا ماڈل ڈاؤن لوڈ نہیں ہو سکا۔ انٹرنیٹ کنکشن چیک کر کے دوبارہ کوشش کریں۔',
  );
  String get deleteOfflineModelAsk => _(
    'حذف نموذج التلاوة من الهاتف؟ سيعود التسميع إلى العمل عبر الإنترنت.',
    'Delete the recitation model from the phone? Reciting will use the internet again.',
    'ফোন থেকে তিলাওয়াত মডেল মুছবেন? তিলাওয়াত যাচাই আবার ইন্টারনেটে চলবে।',
    'فون سے تلاوت کا ماڈل حذف کریں؟ تسمیع پھر انٹرنیٹ سے چلے گی۔',
  );
}
