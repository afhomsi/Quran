part of 'strings.dart';

/// Texts of the word card and the study panel: tafsir, qira'at, word
/// analysis, i'rab, reflections and translation.
extension StudyStrings on S {
  // The four parts of the study panel.
  String get surahSciences =>
      _('علوم السورة', 'About the surah', 'সূরা পরিচিতি', 'علوم السورۃ');
  String get studyPage => _('الصفحة', 'Page', 'পৃষ্ঠা', 'صفحہ');
  String get studyAyah => _('الآية', 'Ayah', 'আয়াত', 'آیت');
  String get studyWord => _('الكلمة', 'Word', 'শব্দ', 'لفظ');

  // Their tabs.
  String get surahNaming => _(
    'تسمية السورة ومقاصدها',
    'Name and aims',
    'নাম ও উদ্দেশ্য',
    'نام اور مقاصد',
  );
  String get surahStats =>
      _('إحصائيات', 'Statistics', 'পরিসংখ্যান', 'اعداد و شمار');
  String get benefits => _('الفوائد', 'Reflections', 'শিক্ষা', 'فوائد');
  String get translations => _('الترجمات', 'Translation', 'অনুবাদ', 'تراجم');
  String get mukhtasar => _('المختصر', 'Brief', 'সংক্ষিপ্ত', 'مختصر');
  String get tafsir => _('التفسير', 'Tafsir', 'তাফসীর', 'تفسیر');
  String get qiraat => _('القراءات', "Qira'at", 'কিরাআত', 'قراءات');
  String get tasreef => _('التصريف', 'Morphology', 'শব্দ বিশ্লেষণ', 'صرف');
  String get irabAyah =>
      _('إعراب الآية', "I'rab of the ayah", 'আয়াতের ই‘রাব', 'آیت کا اعراب');
  String get irab => _('الإعراب', "I'rab", 'ই‘রাব', 'اعراب');
  String get tadabbur => _('التدبر', 'Reflection', 'চিন্তা', 'تدبر');
  String get translation => _('الترجمة', 'Translation', 'অনুবাদ', 'ترجمہ');
  String get meaning => _('المعنى', 'Meaning', 'অর্থ', 'معنی');

  String bookName(StudyBook book) => switch (book) {
    StudyBook.mukhtasar => _(
      'المختصر في التفسير',
      'Al-Mukhtasar',
      'আল-মুখতাসার',
      'المختصر فی التفسیر',
    ),
    StudyBook.muyassar => _('الميسر', 'Al-Muyassar', 'আল-মুয়াসসার', 'المیسر'),
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
    StudyBook.qiraat => _(
      'الموسوعة القرآنية',
      "Mawsu'at al-Qira'at",
      'কিরাআত বিশ্বকোষ',
      'الموسوعۃ القرآنیۃ',
    ),
    StudyBook.tasreef => _(
      'تحليل كلمات القرآن',
      "Tahlil Kalimat al-Qur'an",
      'শব্দ বিশ্লেষণ',
      'تحلیل کلمات القرآن',
    ),
    StudyBook.irabMuyassar => _(
      'الإعراب الميسر',
      "Al-I'rab al-Muyassar",
      'সহজ ই‘রাব',
      'الاعراب المیسر',
    ),
    StudyBook.irabJadwal => _('الجدول', 'Al-Jadwal', 'আল-জাদওয়াল', 'الجدول'),
    StudyBook.irabDarwish => _('درويش', 'Ad-Darwish', 'আদ-দারবীশ', 'درویش'),
    StudyBook.gharib => _(
      'الميسر في الغريب',
      'Al-Muyassar fil-Gharib',
      'বিরল শব্দের অর্থ',
      'المیسر فی الغریب',
    ),
    StudyBook.tadabbur => _(
      'تدبر وعمل',
      "Tadabbur wa 'Amal",
      'তাদাব্বুর ওয়া আমাল',
      'تدبر و عمل',
    ),
    StudyBook.english => _(
      'صحيح إنترناشونال',
      'Saheeh International',
      'সহীহ ইন্টারন্যাশনাল',
      'صحیح انٹرنیشنل',
    ),
  };

  // The word card.
  String get chooseContent => _(
    'اختر نوع المحتوى',
    'Choose the content',
    'বিষয় বেছে নিন',
    'مواد چنیں',
  );
  String get bookmarkAction => _('فاصل', 'Bookmark', 'বুকমার্ক', 'نشان');
  String get colorAction => _('تلوين', 'Color', 'রং', 'رنگ');
  String get comments => _('تعليقات', 'Notes', 'নোট', 'تبصرے');
  String get comment => _('تعليق', 'Note', 'নোট', 'تبصرہ');
  String get removeColor =>
      _('إزالة التلوين', 'Remove color', 'রং সরান', 'رنگ ہٹائیں');
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
  String get wordTranslationNote => _(
    'ترجمة الآية كاملة:',
    'Translation of the whole ayah:',
    'পুরো আয়াতের অনুবাদ:',
    'پوری آیت کا ترجمہ:',
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
}
