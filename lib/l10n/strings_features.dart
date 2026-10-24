part of 'strings.dart';

/// Texts of the tabs, khatma plans, bookmarks, notes, self-test and the
/// audio player.
extension FeatureStrings on S {
  // Bottom tabs.
  String get tabKhatma => _('ختمة', 'Khatma', 'খতম', 'ختم');
  String get tabIndex => _('الفهرس', 'Index', 'সূচি', 'فہرست');
  String get tabBookmarks =>
      _('علاماتي', 'My marks', 'আমার চিহ্ন', 'میرے نشان');
  String get tabMore => _('المزيد', 'More', 'আরও', 'مزید');

  // Mushaf top bar and menu.
  String get menu => _('القائمة', 'Menu', 'মেনু', 'مینو');
  String get dayMode =>
      _('الوضع النهاري', 'Day mode', 'দিনের মোড', 'دن کا موڈ');
  String get textView =>
      _('عرض النص', 'Text view', 'লেখা দেখুন', 'متن کا منظر');
  String get pageView =>
      _('عرض الصفحة', 'Page view', 'পৃষ্ঠা দেখুন', 'صفحے کا منظر');
  String get pageNavigator => _(
    'التنقل بين الصفحات',
    'Go through the pages',
    'পৃষ্ঠাগুলোতে যান',
    'صفحات میں جائیں',
  );

  /// "1 Al-Fatihah (7)" in the running header: number, name, ayah count.
  String surahHeader(Surah s) =>
      '${n(s.number)} ${surahName(s)} (${n(s.ayahCount)})';

  /// "Juz 1 (1/8)" in the running header: the juz and which of its eight
  /// quarters the page is in.
  String juzHeader(int j, int eighth) => '${juz(j)} (${n(eighth)}/${n(8)})';
  String get searchQuran =>
      _('بحث في القرآن', 'Search the Quran', 'কুরআনে খুঁজুন', 'قرآن میں تلاش');
  String get searchQuranHint => _(
    'اكتب كلمة من الآية',
    'Type a word of the ayah',
    'আয়াতের একটি শব্দ লিখুন',
    'آیت کا کوئی لفظ لکھیں',
  );
  String searchResults(int count, {bool more = false}) => _(
    '${n(count)}${more ? '+' : ''} نتيجة',
    '${n(count)}${more ? '+' : ''} results',
    '${n(count)}${more ? '+' : ''}টি ফলাফল',
    '${n(count)}${more ? '+' : ''} نتائج',
  );
  String get listen => _('استماع', 'Listen', 'শুনুন', 'سنیں');
  String get playFromHere => _(
    'استمع من هذه الآية',
    'Listen from this ayah',
    'এই আয়াত থেকে শুনুন',
    'اس آیت سے سنیں',
  );
  String clock(int hour, int minute) {
    final am = hour < 12;
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final mm = n(minute).padLeft(2, n(0));
    return _(
      '${n(h)}:$mm ${am ? 'ص' : 'م'}',
      '${n(h)}:$mm ${am ? 'AM' : 'PM'}',
      '${n(h)}:$mm ${am ? 'AM' : 'PM'}',
      '${n(h)}:$mm ${am ? 'صبح' : 'شام'}',
    );
  }

  // Ayah menu.
  String setMarker(MarkerKind kind) => _(
    'ضع ${markerName(kind)} هنا',
    'Put the ${markerName(kind)} here',
    '${markerName(kind)} এখানে রাখুন',
    '${markerName(kind)} یہاں لگائیں',
  );
  String removeMarker(MarkerKind kind) => _(
    'أزل ${markerName(kind)}',
    'Remove the ${markerName(kind)}',
    '${markerName(kind)} সরান',
    '${markerName(kind)} ہٹائیں',
  );
  String get highlightAyah =>
      _('تلوين الآية', 'Highlight', 'আয়াত রাঙান', 'آیت رنگیں');
  String get removeHighlight =>
      _('إزالة اللون', 'No color', 'রং সরান', 'رنگ ہٹائیں');
  String get addNote =>
      _('إضافة تعليق', 'Add a note', 'নোট যোগ করুন', 'نوٹ شامل کریں');
  String get editNote =>
      _('تعديل التعليق', 'Edit the note', 'নোট সম্পাদনা', 'نوٹ میں ترمیم');

  // Markers and highlights.
  String markerName(MarkerKind kind) => switch (kind) {
    MarkerKind.reading => _(
      'علامة القراءة',
      'reading mark',
      'পড়ার চিহ্ন',
      'تلاوت کا نشان',
    ),
    MarkerKind.hifz => _(
      'علامة الحفظ',
      'hifz mark',
      'হিফজের চিহ্ন',
      'حفظ کا نشان',
    ),
    MarkerKind.review => _(
      'علامة المراجعة',
      'review mark',
      'পুনরাবৃত্তির চিহ্ন',
      'دہرائی کا نشان',
    ),
  };
  String noMarker(MarkerKind kind) => _(
    'لم تضع ${markerName(kind)} بعد. اضغط مطولًا على آية في المصحف لوضعها.',
    'No ${markerName(kind)} yet. Long-press an ayah in the mushaf to set it.',
    'এখনো ${markerName(kind)} নেই। মুসহাফে কোনো আয়াত চেপে ধরে রাখুন।',
    'ابھی ${markerName(kind)} نہیں۔ مصحف میں آیت کو دیر تک دبائیں۔',
  );
  String get highlights => _('تلوين', 'Highlights', 'রঙিন আয়াত', 'رنگین آیات');
  String get filterByColor => _(
    'تصفية حسب اللون',
    'Filter by color',
    'রং অনুযায়ী ছাঁকুন',
    'رنگ کے مطابق چھانٹیں',
  );
  String get allColors => _('كل الألوان', 'All colors', 'সব রং', 'تمام رنگ');
  List<String> get colorNames => [
    _('أصفر', 'Yellow', 'হলুদ', 'پیلا'),
    _('أخضر', 'Green', 'সবুজ', 'سبز'),
    _('أزرق', 'Blue', 'নীল', 'نیلا'),
    _('وردي', 'Pink', 'গোলাপি', 'گلابی'),
    _('برتقالي', 'Orange', 'কমলা', 'نارنجی'),
    _('بنفسجي', 'Purple', 'বেগুনি', 'جامنی'),
    _('أحمر', 'Red', 'লাল', 'سرخ'),
    _('فيروزي', 'Turquoise', 'ফিরোজা', 'فیروزی'),
    _('رمادي', 'Grey', 'ধূসর', 'سرمئی'),
    _('بني', 'Brown', 'বাদামি', 'بھورا'),
  ];
  String get noHighlights => _(
    'لا توجد آيات ملونة بعد. اضغط مطولًا على آية لتلوينها.',
    'No highlighted ayat yet. Long-press an ayah to color it.',
    'এখনো কোনো রঙিন আয়াত নেই। রাঙাতে আয়াত চেপে ধরে রাখুন।',
    'ابھی کوئی رنگین آیت نہیں۔ رنگنے کے لیے آیت کو دیر تک دبائیں۔',
  );
  String get noHighlightsInColor => _(
    'لا توجد آيات بهذا اللون.',
    'No ayat in this color.',
    'এই রঙে কোনো আয়াত নেই।',
    'اس رنگ میں کوئی آیت نہیں۔',
  );
  String get savedAyat =>
      _('آيات محفوظة', 'Saved ayat', 'সংরক্ষিত আয়াত', 'محفوظ آیات');
  String get noSavedAyat => _(
    'لا توجد آيات محفوظة بعد.',
    'No saved ayat yet.',
    'এখনো কোনো সংরক্ষিত আয়াত নেই।',
    'ابھی کوئی محفوظ آیت نہیں۔',
  );
  String get delete => _('حذف', 'Delete', 'মুছুন', 'حذف کریں');

  /// "البقرة : الآية 177".
  String surahAyah(Surah s, int ayah) => _(
    '${surahName(s)} : الآية ${n(ayah)}',
    '${surahName(s)} : ayah ${n(ayah)}',
    '${surahName(s)} : আয়াত ${n(ayah)}',
    '${surahName(s)} : آیت ${n(ayah)}',
  );
  String pageAndAyah(int page, int ayah) => _(
    'الصفحة ${n(page)} - الآية ${n(ayah)}',
    'Page ${n(page)} - ayah ${n(ayah)}',
    'পৃষ্ঠা ${n(page)} - আয়াত ${n(ayah)}',
    'صفحہ ${n(page)} - آیت ${n(ayah)}',
  );

  // Khatma.
  String get myKhatmas => _('ختمتي', 'My khatmas', 'আমার খতম', 'میرے ختم');
  String get newKhatma => _('ختمة جديدة', 'New khatma', 'নতুন খতম', 'نیا ختم');
  String get noKhatma => _(
    'لا توجد ختمة بعد.\nابدأ خطة لختم القرآن واتبع وردك كل يوم.',
    'No khatma yet.\nStart a plan to read the whole Quran, a portion a day.',
    'এখনো কোনো খতম নেই।\nপুরো কুরআন পড়ার একটি পরিকল্পনা শুরু করুন।',
    'ابھی کوئی ختم نہیں۔\nپورا قرآن پڑھنے کا منصوبہ شروع کریں۔',
  );
  String get chooseKhatmaType => _(
    'اختر نوع الختمة',
    'Choose the kind of khatma',
    'খতমের ধরন বেছে নিন',
    'ختم کی قسم چنیں',
  );
  String get close => _('إغلاق', 'Close', 'বন্ধ', 'بند کریں');
  String get next => _('التالي', 'Next', 'পরবর্তী', 'اگلا');
  String khatmaTitle(KhatmaType type) => switch (type) {
    KhatmaType.salaf => _(
      'تحزيب السلف',
      'Hizb of the Salaf',
      'সালাফের হিযব',
      'سلف کی حزب بندی',
    ),
    KhatmaType.ramadan => _(
      'ختمة رمضان',
      'Ramadan khatma',
      'রমজানের খতম',
      'رمضان کا ختم',
    ),
    KhatmaType.dailyWird => _(
      'الورد اليومي',
      'Daily wird',
      'দৈনিক ওয়িরদ',
      'روزانہ ورد',
    ),
    KhatmaType.custom => _(
      'ختمة مخصصة',
      'Custom khatma',
      'নিজস্ব খতম',
      'اپنی مرضی کا ختم',
    ),
  };
  String khatmaSubtitle(KhatmaType type) => switch (type) {
    KhatmaType.salaf => _(
      'ختم القرآن في ${n(7)} أيام',
      'The whole Quran in ${n(7)} days',
      '${n(7)} দিনে পুরো কুরআন',
      '${n(7)} دن میں پورا قرآن',
    ),
    KhatmaType.ramadan => _(
      'جزء واحد يوميًا',
      'One juz a day',
      'প্রতিদিন এক পারা',
      'روزانہ ایک پارہ',
    ),
    KhatmaType.dailyWird => _(
      'صفحتين بعد كل صلاة',
      'Two pages after each prayer',
      'প্রতি নামাজের পর দুই পৃষ্ঠা',
      'ہر نماز کے بعد دو صفحے',
    ),
    KhatmaType.custom => _(
      'خصص الختمة كما تريد',
      'Pick your own number of days',
      'নিজের মতো দিন বেছে নিন',
      'اپنی مرضی کے دن چنیں',
    ),
  };
  String get createPlan =>
      _('إنشاء خطة', 'Create plan', 'পরিকল্পনা তৈরি', 'منصوبہ بنائیں');
  String get planBookmark => _(
    'العلامة المرجعية:',
    'Bookmark color:',
    'বুকমার্কের রং:',
    'نشان کا رنگ:',
  );
  String bookmarkColor(int i) => _(
    'لون العلامة ${n(i)}',
    'Bookmark color ${n(i)}',
    'বুকমার্কের রং ${n(i)}',
    'نشان کا رنگ ${n(i)}',
  );
  String get planTitle =>
      _('عنوان الخطة:', 'Plan title:', 'পরিকল্পনার নাম:', 'منصوبے کا نام:');
  String defaultPlanTitle(String date) => _(
    'ختمتي ($date)',
    'My khatma ($date)',
    'আমার খতম ($date)',
    'میرا ختم ($date)',
  );
  String get clear => _('مسح', 'Clear', 'মুছুন', 'صاف کریں');
  String get khatmaDays => _(
    'عدد أيام الختمة:',
    'Number of days:',
    'দিনের সংখ্যা:',
    'دنوں کی تعداد:',
  );
  String get daysRange => _(
    'أدخل عددًا من 1 إلى 604',
    'Enter a number from 1 to 604',
    '১ থেকে ৬০৪ এর মধ্যে একটি সংখ্যা দিন',
    '1 سے 604 تک کوئی عدد لکھیں',
  );
  String pagesPerDay(String pages) => _(
    'حوالي $pages صفحة في اليوم',
    'About $pages pages a day',
    'প্রতিদিন প্রায় $pages পৃষ্ঠা',
    'روزانہ تقریباً $pages صفحے',
  );
  String pages(int first, int last) => first == last
      ? page(first)
      : _(
          'الصفحات ${n(first)} – ${n(last)}',
          'Pages ${n(first)} – ${n(last)}',
          'পৃষ্ঠা ${n(first)} – ${n(last)}',
          'صفحات ${n(first)} – ${n(last)}',
        );
  String fromAyah(Surah s, int ayah) => _(
    'من ${surahName(s)} ${n(ayah)}',
    'from ${surahName(s)} ${n(ayah)}',
    '${surahName(s)} ${n(ayah)} থেকে',
    '${surahName(s)} ${n(ayah)} سے',
  );
  String afterPrayer(int prayer) {
    final names = [
      _('الفجر', 'Fajr', 'ফজর', 'فجر'),
      _('الظهر', 'Dhuhr', 'যোহর', 'ظہر'),
      _('العصر', 'Asr', 'আসর', 'عصر'),
      _('المغرب', 'Maghrib', 'মাগরিব', 'مغرب'),
      _('العشاء', 'Isha', 'এশা', 'عشاء'),
    ];
    return _(
      'بعد ${names[prayer]}',
      'After ${names[prayer]}',
      '${names[prayer]}-এর পর',
      '${names[prayer]} کے بعد',
    );
  }

  String dayOf(int day, int days) => _(
    'اليوم ${n(day)} من ${n(days)}',
    'Day ${n(day)} of ${n(days)}',
    '${n(days)} দিনের ${n(day)}তম দিন',
    '${n(days)} میں سے دن ${n(day)}',
  );
  String day(int day) =>
      _('اليوم ${n(day)}', 'Day ${n(day)}', 'দিন ${n(day)}', 'دن ${n(day)}');
  String get today => _('اليوم', 'today', 'আজ', 'آج');
  String doneOf(int done, int total) => _(
    'أنجزت ${n(done)} من ${n(total)}',
    '${n(done)} of ${n(total)} done',
    '${n(total)}টির মধ্যে ${n(done)}টি সম্পন্ন',
    '${n(total)} میں سے ${n(done)} مکمل',
  );
  String get khatmaComplete => _(
    'تمت الختمة، تقبل الله منك 🎉',
    'Khatma complete, may Allah accept it 🎉',
    'খতম সম্পন্ন, আল্লাহ কবুল করুন 🎉',
    'ختم مکمل، اللہ قبول فرمائے 🎉',
  );
  String nextPortion(int day) => _(
    'الورد التالي (اليوم ${n(day)}):',
    'Next portion (day ${n(day)}):',
    'পরবর্তী অংশ (দিন ${n(day)}):',
    'اگلا حصہ (دن ${n(day)}):',
  );
  String get readPortion => _('اقرأ الورد', 'Read it', 'পড়ুন', 'پڑھیں');
  String get markRead => _('قرأته', 'Done', 'পড়েছি', 'پڑھ لیا');
  String get deleteKhatma =>
      _('حذف الختمة', 'Delete khatma', 'খতম মুছুন', 'ختم حذف کریں');
  String get deleteKhatmaQuestion => _(
    'حذف الختمة؟',
    'Delete this khatma?',
    'খতমটি মুছবেন?',
    'یہ ختم حذف کریں؟',
  );
  String deleteKhatmaExplain(String title) => _(
    'سيتم حذف "$title" وما أنجزته فيها.',
    '"$title" and its progress will be deleted.',
    '"$title" ও এর অগ্রগতি মুছে যাবে।',
    '"$title" اور اس کی پیش رفت حذف ہو جائے گی۔',
  );
  String get openInMushaf => _(
    'افتح في المصحف',
    'Open in the mushaf',
    'মুসহাফে খুলুন',
    'مصحف میں کھولیں',
  );

  // More.
  String get selfTest => _(
    'اختبار ذاتي للحفظ',
    'Hifz self-test',
    'হিফজ আত্ম-পরীক্ষা',
    'حفظ کا خود امتحان',
  );
  String get recitationCheck => _(
    'تسميع مع تنبيه الأخطاء',
    'Recite with mistake alerts',
    'ভুল সতর্কতাসহ তিলাওয়াত',
    'غلطیوں کی نشاندہی کے ساتھ تسمیع',
  );
  String get myNotes => _('تعليقاتي', 'My notes', 'আমার নোট', 'میرے نوٹ');

  // Notes.
  String get noNotes => _(
    'لا توجد تعليقات بعد.\nاضغط مطولًا على آية في المصحف واختر "إضافة تعليق".',
    'No notes yet.\nLong-press an ayah in the mushaf and choose "Add a note".',
    'এখনো কোনো নোট নেই।\nমুসহাফে আয়াত চেপে ধরে "নোট যোগ করুন" বেছে নিন।',
    'ابھی کوئی نوٹ نہیں۔\nمصحف میں آیت کو دیر تک دبا کر "نوٹ شامل کریں" چنیں۔',
  );
  String get noteOnAyah =>
      _('تعليق على الآية', 'Note on the ayah', 'আয়াতের নোট', 'آیت پر نوٹ');
  String get noteHint => _(
    'اكتب تعليقك أو فائدة عن الآية',
    'Write your note or a lesson from the ayah',
    'আয়াত সম্পর্কে আপনার নোট লিখুন',
    'آیت کے بارے میں اپنا نوٹ لکھیں',
  );
  String get save => _('حفظ', 'Save', 'সংরক্ষণ', 'محفوظ کریں');
  String ayahOnPage(Surah s, int ayah, int page) => _(
    '${surahName(s)} · الآية ${n(ayah)} · الصفحة ${n(page)}',
    '${surahName(s)} · ayah ${n(ayah)} · page ${n(page)}',
    '${surahName(s)} · আয়াত ${n(ayah)} · পৃষ্ঠা ${n(page)}',
    '${surahName(s)} · آیت ${n(ayah)} · صفحہ ${n(page)}',
  );

  // Self-test.
  String get whatToTest => _(
    'ماذا تريد أن تختبر؟',
    'What do you want to test?',
    'কী পরীক্ষা করতে চান?',
    'کس حصے کا امتحان؟',
  );
  String get surahWord => _('سورة', 'Surah', 'সূরা', 'سورت');
  String get juzWord => _('جزء', 'Juz', 'পারা', 'پارہ');
  String get whatIMemorized =>
      _('ما حفظته', 'What I know', 'যা মুখস্থ', 'جو حفظ ہے');
  String get noHifzMarker => _(
    'لم تضع علامة الحفظ بعد. اضغط مطولًا على آخر آية حفظتها في المصحف '
        'واختر "ضع علامة الحفظ هنا".',
    'No hifz mark yet. Long-press the last ayah you memorized in the '
        'mushaf and put the hifz mark there.',
    'এখনো হিফজের চিহ্ন নেই। মুসহাফে আপনার মুখস্থ শেষ আয়াতে চেপে ধরে '
        'হিফজের চিহ্ন রাখুন।',
    'ابھی حفظ کا نشان نہیں۔ مصحف میں آخری حفظ شدہ آیت کو دیر تک دبا کر '
        'حفظ کا نشان لگائیں۔',
  );
  String upToHifz(Surah s, int ayah) => _(
    'من أول المصحف حتى ${surahName(s)} الآية ${n(ayah)}',
    'From the start of the mushaf to ${surahName(s)} ayah ${n(ayah)}',
    'মুসহাফের শুরু থেকে ${surahName(s)} আয়াত ${n(ayah)} পর্যন্ত',
    'مصحف کے شروع سے ${surahName(s)} آیت ${n(ayah)} تک',
  );
  String get questionType =>
      _('نوع السؤال', 'Kind of question', 'প্রশ্নের ধরন', 'سوال کی قسم');
  String get whatComesNext => _(
    'ما الآية التالية؟',
    'Which ayah comes next?',
    'পরের আয়াত কোনটি?',
    'اگلی آیت کون سی ہے؟',
  );
  String get whatComesNextExplain => _(
    'تظهر آية وتسمّع الآية التي بعدها',
    'See an ayah and recite the one after it',
    'একটি আয়াত দেখে পরেরটি তিলাওয়াত করুন',
    'ایک آیت دیکھ کر اگلی آیت سنائیں',
  );
  String get completeTheAyah => _(
    'أكمل الآية',
    'Complete the ayah',
    'আয়াতটি পূর্ণ করুন',
    'آیت مکمل کریں',
  );
  String get completeTheAyahExplain => _(
    'تظهر بداية الآية وتكمل الباقي',
    'See the start of an ayah and recite the rest',
    'আয়াতের শুরু দেখে বাকিটা তিলাওয়াত করুন',
    'آیت کا شروع دیکھ کر باقی سنائیں',
  );
  String questionCount(int count) => _(
    'عدد الأسئلة: ${n(count)}',
    'Questions: ${n(count)}',
    'প্রশ্ন: ${n(count)}',
    'سوالات: ${n(count)}',
  );
  String get startTest =>
      _('ابدأ الاختبار', 'Start the test', 'পরীক্ষা শুরু', 'امتحان شروع کریں');
  String questionOf(int i, int total) => _(
    'السؤال ${n(i)} من ${n(total)}',
    'Question ${n(i)} of ${n(total)}',
    '${n(total)}টির মধ্যে প্রশ্ন ${n(i)}',
    '${n(total)} میں سے سوال ${n(i)}',
  );
  String get showAnswer =>
      _('أظهر الإجابة', 'Show the answer', 'উত্তর দেখুন', 'جواب دکھائیں');
  String get gotItRight => _('أصبت', 'I got it', 'পেরেছি', 'درست');
  String get gotItWrong => _('أخطأت', 'I missed it', 'ভুল হয়েছে', 'غلط');
  String score(int right, int total) => _(
    'النتيجة: ${n(right)} من ${n(total)}',
    'Score: ${n(right)} of ${n(total)}',
    'ফলাফল: ${n(total)}টির মধ্যে ${n(right)}',
    'نتیجہ: ${n(total)} میں سے ${n(right)}',
  );
  String get reviewThese => _(
    'راجع هذه الآيات:',
    'Review these ayat:',
    'এই আয়াতগুলো আবার দেখুন:',
    'یہ آیات دہرائیں:',
  );
  String get newTest =>
      _('اختبار جديد', 'New test', 'নতুন পরীক্ষা', 'نیا امتحان');

  // Audio.
  String get closePlayer =>
      _('إغلاق المشغل', 'Close the player', 'প্লেয়ার বন্ধ', 'پلیئر بند کریں');
  String get nextAyah =>
      _('الآية التالية', 'Next ayah', 'পরের আয়াত', 'اگلی آیت');
  String get previousAyah =>
      _('الآية السابقة', 'Previous ayah', 'আগের আয়াত', 'پچھلی آیت');
  String get play => _('تشغيل', 'Play', 'চালান', 'چلائیں');
  String get pause => _('إيقاف مؤقت', 'Pause', 'বিরতি', 'وقفہ');
  String get audioOptions => _(
    'خيارات التلاوة',
    'Recitation options',
    'তিলাওয়াতের বিকল্প',
    'تلاوت کے اختیارات',
  );
  String get audioError => _(
    'تعذر تشغيل التلاوة، تحقق من الاتصال بالإنترنت',
    'Could not play the recitation. Check the internet connection.',
    'তিলাওয়াত চালানো যায়নি। ইন্টারনেট সংযোগ দেখুন।',
    'تلاوت نہیں چل سکی۔ انٹرنیٹ کنکشن دیکھیں۔',
  );
  String loopLabel(AudioLoop loop) => switch (loop) {
    AudioLoop.none => _(
      'بدون تكرار',
      'No repeat',
      'পুনরাবৃত্তি নেই',
      'دہرائی نہیں',
    ),
    AudioLoop.ayah => _(
      'تكرار الآية',
      'Repeat the ayah',
      'আয়াত পুনরাবৃত্তি',
      'آیت دہرائیں',
    ),
    AudioLoop.page => _(
      'تكرار الصفحة',
      'Repeat the page',
      'পৃষ্ঠা পুনরাবৃত্তি',
      'صفحہ دہرائیں',
    ),
    AudioLoop.surah => _(
      'تكرار السورة',
      'Repeat the surah',
      'সূরা পুনরাবৃত্তি',
      'سورت دہرائیں',
    ),
  };
  String loopShort(AudioLoop loop) => switch (loop) {
    AudioLoop.none => _('أكمل', 'Go on', 'চালিয়ে যান', 'جاری'),
    AudioLoop.ayah => _('الآية', 'Ayah', 'আয়াত', 'آیت'),
    AudioLoop.page => _('الصفحة', 'Page', 'পৃষ্ঠা', 'صفحہ'),
    AudioLoop.surah => _('السورة', 'Surah', 'সূরা', 'سورت'),
  };
  String reciterName(Reciter r) => switch (language) {
    AppLanguage.ar || AppLanguage.ur => r.name,
    AppLanguage.en || AppLanguage.bn => r.latinName,
  };
  String get reciter => _('القارئ', 'Reciter', 'ক্বারী', 'قاری');
  String repeatEachAyah(int times) => _(
    'تكرار كل آية: ${n(times)} ${times == 1 ? 'مرة' : 'مرات'}',
    'Play each ayah: ${n(times)} ${times == 1 ? 'time' : 'times'}',
    'প্রতিটি আয়াত: ${n(times)} বার',
    'ہر آیت: ${n(times)} بار',
  );
  String get whenFinished =>
      _('عند انتهاء التلاوة', 'At the end', 'শেষ হলে', 'ختم ہونے پر');
  String speed(double speed) => _(
    'سرعة التلاوة: $speed×',
    'Speed: $speed×',
    'গতি: $speed×',
    'رفتار: $speed×',
  );
  String get audioSource => _(
    'التلاوات من موقع everyayah.com وتحتاج اتصالًا بالإنترنت.',
    'Recitations come from everyayah.com and need an internet connection.',
    'তিলাওয়াত everyayah.com থেকে আসে, ইন্টারনেট সংযোগ লাগে।',
    'تلاوتیں everyayah.com سے آتی ہیں اور انٹرنیٹ درکار ہے۔',
  );

  // Sources and rights.
  String get sources => _(
    'المصادر والحقوق',
    'Sources and rights',
    'উৎস ও স্বত্ব',
    'ماخذ اور حقوق',
  );
  String get sourceQuranText =>
      _('نص القرآن', 'Quran text', 'কুরআনের পাঠ', 'قرآن کا متن');
  String get sourceMushaf =>
      _('صفحات المصحف', 'Mushaf pages', 'মুসহাফের পৃষ্ঠা', 'مصحف کے صفحات');
  String get sourceTafsir => _(
    'التفسير والقراءات والإعراب',
    "Tafsir, qira'at and i'rab",
    'তাফসীর, কিরাআত ও ই‘রাব',
    'تفسیر، قراءات اور اعراب',
  );
  String get sourceTranslation => _(
    'الترجمة الإنجليزية',
    'English translation',
    'ইংরেজি অনুবাদ',
    'انگریزی ترجمہ',
  );
  String get sourceRecitations =>
      _('التلاوات', 'Recitations', 'তিলাওয়াত', 'تلاوتیں');
  String get softwareLicences => _(
    'تراخيص البرمجيات المستخدمة',
    'Software licences',
    'সফটওয়্যার লাইসেন্স',
    'سافٹ ویئر لائسنس',
  );
}
