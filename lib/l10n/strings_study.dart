part of 'strings.dart';

/// Texts of the word card and the study panel: tafsir, qira'at, i'rab and
/// translation.
extension StudyStrings on S {
  // The four parts of the study panel.
  String get surahSciences =>
      _('علوم السورة', 'About the surah', 'সূরা পরিচিতি', 'علوم السورۃ');
  String get studyPage => _('الصفحة', 'Page', 'পৃষ্ঠা', 'صفحہ');
  String get studyAyah => _('الآية', 'Ayah', 'আয়াত', 'آیت');
  String get studyWord => _('الكلمة', 'Word', 'শব্দ', 'لفظ');

  // Their tabs.
  String get surahStats =>
      _('إحصائيات', 'Statistics', 'পরিসংখ্যান', 'اعداد و شمار');
  String get translations => _('الترجمات', 'Translation', 'অনুবাদ', 'تراجم');
  String get mukhtasar => _('المختصر', 'Brief', 'সংক্ষিপ্ত', 'مختصر');
  String get tafsir => _('التفسير', 'Tafsir', 'তাফসীর', 'تفسیر');
  String get qiraat => _('القراءات', "Qira'at", 'কিরাআত', 'قراءات');
  String get irabAyah =>
      _('إعراب الآية', "I'rab of the ayah", 'আয়াতের ই‘রাব', 'آیت کا اعراب');
  String get irab => _('الإعراب', "I'rab", 'ই‘রাব', 'اعراب');
  String get translation => _('الترجمة', 'Translation', 'অনুবাদ', 'ترجمہ');
  String get meaning => _('المعنى', 'Meaning', 'অর্থ', 'معنی');

  String bookName(StudyBook book) => switch (book) {
    StudyBook.jalalayn => _(
      'تفسير الجلالين',
      'Tafsir al-Jalalayn',
      'তাফসীরে জালালাইন',
      'تفسیر جلالین',
    ),
    StudyBook.saadi => _('السعدي', "As-Sa'di", 'আস-সা‘দী', 'السعدی'),
    StudyBook.ibnKathir => _(
      'ابن كثير',
      'Ibn Kathir',
      'ইবনে কাসীর',
      'ابن کثیر',
    ),
    StudyBook.baghawi => _('البغوي', 'Al-Baghawi', 'আল-বাগাভী', 'البغوی'),
    StudyBook.tabari => _('الطبري', 'At-Tabari', 'আত-তাবারী', 'الطبری'),
    StudyBook.nashr => _(
      'النشر لابن الجزري',
      'An-Nashr (Ibn al-Jazari)',
      'আন-নাশর',
      'النشر لابن الجزری',
    ),
    StudyBook.samin => _(
      'الدر المصون للسمين الحلبي',
      'Ad-Durr al-Masun (as-Samin al-Halabi)',
      'আদ-দুররুল মাসূন',
      'الدر المصون للسمین الحلبی',
    ),
    StudyBook.english => _('ترجمة بكثال', 'Pickthall', 'পিকথল', 'پکتھال'),
  };

  // The word card.
  String get chooseContent => _(
    'اختر نوع المحتوى',
    'Choose the content',
    'বিষয় বেছে নিন',
    'مواد چنیں',
  );
  String get bookmarkAction => _('علامة', 'Bookmark', 'বুকমার্ক', 'نشان');
  String get colorAction => _('تظليل', 'Highlight', 'রং', 'رنگ');
  String get comments => _('ملاحظات', 'Notes', 'নোট', 'نوٹس');
  String get studyMore => _('تفاصيل', 'Details', 'বিস্তারিত', 'تفصیل');
  String get comment => _('تعليق', 'Note', 'নোট', 'تبصرہ');
  String get removeColor =>
      _('إزالة التظليل', 'Remove highlight', 'রং সরান', 'رنگ ہٹائیں');
  String get bookmarkAdded => _(
    'تمت إضافة العلامة المرجعية',
    'Bookmark added',
    'বুকমার্ক যোগ হয়েছে',
    'نشان لگ گیا',
  );
  String get bookmarkRemoved => _(
    'أزيلت العلامة المرجعية',
    'Bookmark removed',
    'বুকমার্ক সরানো হয়েছে',
    'نشان ہٹ گیا',
  );
  String get noWordMeaning => _(
    'لا توجد ترجمة لهذه الكلمة.',
    'No meaning for this word.',
    'এই শব্দের অর্থ নেই।',
    'اس لفظ کا ترجمہ نہیں ملا۔',
  );
  String noWordEntry(StudyBook book) => _(
    'لا يوجد في «${bookName(book)}» كلام خاص بهذه الكلمة.',
    'Nothing on this word in ${bookName(book)}.',
    '${bookName(book)}-এ এই শব্দ নিয়ে কিছু নেই।',
    '«${bookName(book)}» میں اس لفظ پر کچھ نہیں۔',
  );
  String noAyahEntry(StudyBook book) => _(
    'لا يوجد في «${bookName(book)}» كلام عن هذه الآية.',
    'Nothing on this ayah in ${bookName(book)}.',
    '${bookName(book)}-এ এই আয়াত নিয়ে কিছু নেই।',
    '«${bookName(book)}» میں اس آیت پر کچھ نہیں۔',
  );
  String source(StudyBook book) => _(
    'المصدر: ${bookName(book)}',
    'Source: ${bookName(book)}',
    'উৎস: ${bookName(book)}',
    'ماخذ: ${bookName(book)}',
  );
  String get studyLoadError => _(
    'تعذر تحميل المحتوى. يحتاج اتصالًا بالإنترنت أول مرة، ثم يُحفظ على الجهاز.',
    'Could not load. It needs internet the first time, then it is kept on '
        'the device.',
    'লোড করা যায়নি। প্রথমবার ইন্টারনেট লাগে, পরে ডিভাইসে থাকে।',
    'لوڈ نہیں ہو سکا۔ پہلی بار انٹرنیٹ چاہیے، پھر آلے پر محفوظ رہتا ہے۔',
  );
  String get retry =>
      _('إعادة المحاولة', 'Try again', 'আবার চেষ্টা করুন', 'دوبارہ کوشش');

  // The study panel's tools.
  String get studyOpen => _(
    'التفسير والمعاني',
    'Tafsir and meanings',
    'তাফসীর ও অর্থ',
    'تفسیر اور معانی',
  );
  String get expand => _('تكبير', 'Expand', 'বড় করুন', 'بڑا کریں');
  String get shrink => _('تصغير', 'Shrink', 'ছোট করুন', 'چھوٹا کریں');
  String get previous => _('السابق', 'Previous', 'পূর্ববর্তী', 'پچھلا');
  String get share => _('مشاركة', 'Share', 'শেয়ার', 'شیئر');
  String get shareCurrent => _(
    'مشاركة المحتوى الحالي',
    'Share what is shown',
    'যা দেখানো হচ্ছে তা শেয়ার করুন',
    'جو دکھایا جا رہا ہے شیئر کریں',
  );
  String get shareAsText =>
      _('مشاركة كنص', 'Share as text', 'লেখা হিসেবে শেয়ার', 'متن کے طور پر');
  String get copyText => _('نسخ النص', 'Copy text', 'লেখা কপি', 'متن کاپی');
  String get copied => _('تم النسخ', 'Copied', 'কপি হয়েছে', 'کاپی ہو گیا');

  // Surah statistics.
  String get statRevelation =>
      _('مكان النزول', 'Revealed in', 'অবতীর্ণ', 'مقام نزول');
  String get statOrder => _(
    'ترتيبها في المصحف',
    'Order in the mushaf',
    'মুসহাফে ক্রম',
    'مصحف میں ترتیب',
  );
  String get statAyat => _('عدد الآيات', 'Ayat', 'আয়াত', 'آیات');
  String get statWords => _('عدد الكلمات', 'Words', 'শব্দ', 'الفاظ');
  String get statLetters => _('عدد الحروف', 'Letters', 'অক্ষর', 'حروف');
  String get statPages => _('الصفحات', 'Pages', 'পৃষ্ঠা', 'صفحات');
  String get statJuz => _('الأجزاء', 'Juz', 'পারা', 'پارے');
  String range(int from, int to) =>
      from == to ? n(from) : '${n(from)} – ${n(to)}';

  // Tajweed.
  String get tajweedTab => _('التجويد', 'Tajweed', 'তাজবীদ', 'تجوید');
  String get tajweedOnPage => _(
    'تلوين المصحف بألوان التجويد',
    'Color the mushaf by tajweed',
    'মুসহাফে তাজবীদের রং',
    'مصحف کو تجوید کے رنگوں میں دکھائیں',
  );
  String get noTajweedHere => _(
    'لا يوجد حكم تجويد ملوّن في هذا الموضع.',
    'No colored tajweed rule here.',
    'এখানে রঙিন তাজবীদের নিয়ম নেই।',
    'یہاں تجوید کا کوئی رنگین حکم نہیں۔',
  );
  String get tajweedLegend =>
      _('دليل الألوان', 'Color guide', 'রঙের নির্দেশিকা', 'رنگوں کی رہنمائی');

  String tajweedName(TajweedRule rule) => switch (rule) {
    TajweedRule.maddLazim => _(
      'مد لازم ٦ حركات',
      'Necessary madd, 6 counts',
      'মাদ্দে লাযিম, ৬ হরকত',
      'مد لازم، ٦ حرکات',
    ),
    TajweedRule.maddWajib => _(
      'مد واجب ٤ أو ٥ حركات',
      'Obligatory madd, 4 or 5 counts',
      'মাদ্দে ওয়াজিব, ৪ বা ৫ হরকত',
      'مد واجب، ٤ یا ٥ حرکات',
    ),
    TajweedRule.maddJaiz => _(
      'مد جائز ٢ أو ٤ أو ٦ حركات',
      'Permissible madd, 2, 4 or 6 counts',
      'মাদ্দে জায়িয, ২, ৪ বা ৬ হরকত',
      'مد جائز، ٢، ٤ یا ٦ حرکات',
    ),
    TajweedRule.maddTabii => _(
      'مد حركتان',
      'Madd of 2 counts',
      'দুই হরকতের মাদ্দ',
      'دو حرکات کا مد',
    ),
    TajweedRule.ghunna => _(
      'إخفاء ومواضع الغنة',
      'Ikhfa and ghunnah',
      'ইখফা ও গুন্নাহ',
      'اخفاء اور غنہ',
    ),
    TajweedRule.tafkhim => _(
      'تفخيم',
      'Heavy letters (tafkhim)',
      'তাফখীম (ভারী উচ্চারণ)',
      'تفخیم',
    ),
    TajweedRule.qalqala => _('قلقلة', 'Qalqalah', 'কলকলা', 'قلقلہ'),
    TajweedRule.silent => _(
      'إدغام وما لا يُلفظ',
      'Merged or silent letters',
      'ইদগাম ও অনুচ্চারিত অক্ষর',
      'ادغام اور جو پڑھا نہ جائے',
    ),
  };

  String tajweedHelp(TajweedRule rule) => switch (rule) {
    TajweedRule.maddLazim => _(
      'يُمد ست حركات إذا جاء بعد حرف المد سكون أصلي، كما في ﴿ٱلضَّآلِّينَ﴾ وفي فواتح السور مثل ﴿الٓمٓ﴾.',
      'Held for 6 counts when a letter of madd is followed by a fixed sukun, '
          'as in ad-dallin and the opening letters of surahs such as Alif Lam Mim.',
      'মাদ্দের অক্ষরের পর স্থায়ী সুকুন এলে ৬ হরকত টানা হয়।',
      'حرف مد کے بعد اصلی سکون ہو تو چھ حرکات کھینچا جاتا ہے۔',
    ),
    TajweedRule.maddWajib => _(
      'يُمد أربع أو خمس حركات إذا جاء بعد حرف المد همزة، في كلمة واحدة مثل ﴿أُوْلَٰٓئِكَ﴾ أو في كلمتين مثل ﴿بِمَآ أُنزِلَ﴾.',
      'Held for 4 or 5 counts when a letter of madd is followed by a hamza, '
          'in the same word or the next one.',
      'মাদ্দের অক্ষরের পর হামযা এলে ৪ বা ৫ হরকত টানা হয়।',
      'حرف مد کے بعد ہمزہ ہو تو چار یا پانچ حرکات کھینچا جاتا ہے۔',
    ),
    TajweedRule.maddJaiz => _(
      'يجوز فيه القصر والتوسط والطول، ومنه المد العارض للسكون عند الوقف، مثل ﴿ٱلۡمُفۡلِحُونَ﴾.',
      'May be held for 2, 4 or 6 counts, such as the madd before a pause.',
      'থামার সময় ২, ৪ বা ৬ হরকত টানা যায়।',
      'وقف کے وقت دو، چار یا چھ حرکات کھینچنا جائز ہے۔',
    ),
    TajweedRule.maddTabii => _(
      'المد الطبيعي وما يلحق به، يُمد حركتين، مثل الألف الصغيرة في ﴿ذَٰلِكَ﴾.',
      'The natural madd, held for 2 counts.',
      'স্বাভাবিক মাদ্দ, ২ হরকত।',
      'طبعی مد، دو حرکات۔',
    ),
    TajweedRule.ghunna => _(
      'تُنطق النون أو الميم بغنة من الأنف مقدار حركتين، كما في ﴿مِن قَبۡلِكَ﴾ و﴿مِمَّا﴾.',
      'The nun or mim is said through the nose for 2 counts.',
      'নূন বা মীম নাক দিয়ে ২ হরকত উচ্চারণ।',
      'نون یا میم ناک سے دو حرکات تک ادا ہو۔',
    ),
    TajweedRule.tafkhim => _(
      'تُنطق حروف الاستعلاء (خص ضغط قظ) والراء المفخمة بامتلاء الفم بصوتها، كما في ﴿صِرَٰطَ﴾.',
      'Heavy letters and the heavy ra fill the mouth with their sound.',
      'ভারী অক্ষর মুখ ভরে উচ্চারণ।',
      'پُر حروف منہ بھر کر ادا ہوں۔',
    ),
    TajweedRule.qalqala => _(
      'يضطرب صوت الحرف الساكن من حروف (قطب جد) حتى تُسمع له نبرة قوية، كما في ﴿قَبۡلِكَ﴾.',
      'A still qaf, ta, ba, jim or dal is said with a slight bounce.',
      'সুকুনযুক্ত ق ط ب ج د প্রতিধ্বনিসহ উচ্চারণ।',
      'ساکن ق ط ب ج د میں جھٹکا ہو۔',
    ),
    TajweedRule.silent => _(
      'حروف تُكتب ولا تُنطق، كهمزة الوصل في وسط الكلام واللام الشمسية، والحرف المدغم فيما بعده، مثل ﴿وَٱلَّذِينَ﴾.',
      'Letters written but not said, such as the joining hamza, the sun lam '
          'and a letter merged into the next.',
      'লেখা কিন্তু উচ্চারিত নয় এমন অক্ষর।',
      'لکھے جانے والے مگر نہ پڑھے جانے والے حروف۔',
    ),
  };

  // Sharing as an image or PDF.
  String get shareAsImage =>
      _('مشاركة صورة', 'Share image', 'ছবি শেয়ার', 'تصویر شیئر');
  String get shareAsPdf =>
      _('مشاركة PDF', 'Share PDF', 'PDF শেয়ার', 'PDF شیئر');
  String get sharePreview =>
      _('معاينة المشاركة', 'Preview', 'প্রিভিউ', 'پیش نظارہ');
  String get appName => _('حفظ القرآن', 'Hifz', 'হিফজ', 'حفظ قرآن');
}
