import 'package:flutter/widgets.dart';

import '../audio/ayah_audio.dart';
import '../data/khatma.dart';
import '../data/marks.dart';
import '../data/quran_models.dart';
import '../settings/app_settings.dart';

part 'strings_features.dart';

/// The app's texts in the language chosen in the settings. Put above the
/// screens by `HifzApp`; read with `S.of(context)`.
class S {
  const S(this.language, {this.westernDigits = true});

  final AppLanguage language;

  /// 123 instead of the language's own digits.
  final bool westernDigits;

  static S of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StringsScope>()?.strings ??
      const S(AppLanguage.ar);

  String _(String ar, String en, String bn, String ur) => switch (language) {
    AppLanguage.ar => ar,
    AppLanguage.en => en,
    AppLanguage.bn => bn,
    AppLanguage.ur => ur,
  };

  /// [number] in the digits of the language, unless western digits are on.
  String n(int number) {
    final digits = westernDigits
        ? null
        : switch (language) {
            AppLanguage.ar => '٠١٢٣٤٥٦٧٨٩',
            AppLanguage.ur => '۰۱۲۳۴۵۶۷۸۹',
            AppLanguage.bn => '০১২৩৪৫৬৭৮৯',
            AppLanguage.en => null,
          };
    final text = '$number';
    if (digits == null) return text;
    return text
        .split('')
        .map((d) => d == '-' ? d : digits[int.parse(d)])
        .join();
  }

  /// The surah's Arabic name, or its name in Latin letters for languages
  /// that are not written in Arabic script.
  String surahName(Surah s) => switch (language) {
    AppLanguage.ar || AppLanguage.ur => s.name,
    AppLanguage.en || AppLanguage.bn => s.transliteration,
  };

  // Home and index.
  String get mushaf => _('المصحف', 'Mushaf', 'মুসহাফ', 'مصحف');
  String get recite => _('تسميع', 'Recite', 'তিলাওয়াত যাচাই', 'تسمیع');
  String get goTo => _(
    'انتقال إلى سورة أو صفحة',
    'Go to a surah or page',
    'সূরা বা পৃষ্ঠায় যান',
    'سورت یا صفحے پر جائیں',
  );
  String get surahAndAyah =>
      _('سورة وآية', 'Surah and ayah', 'সূরা ও আয়াত', 'سورت اور آیت');
  String get pageWord => _('صفحة', 'Page', 'পৃষ্ঠা', 'صفحہ');
  String get surahField => _('السورة', 'Surah', 'সূরা', 'سورت');

  /// "الآية", with the range of ayat once the surah is known.
  String ayahField(int? count) {
    final range = count == null ? '' : ' (${n(1)} – ${n(count)})';
    return _('الآية$range', 'Ayah$range', 'আয়াত$range', 'آیت$range');
  }

  String get settings => _('الإعدادات', 'Settings', 'সেটিংস', 'ترتیبات');
  String continueReading(int page) => _(
    'متابعة القراءة · صفحة ${n(page)}',
    'Continue reading · page ${n(page)}',
    'পড়া চালিয়ে যান · পৃষ্ঠা ${n(page)}',
    'پڑھنا جاری رکھیں · صفحہ ${n(page)}',
  );
  String loadMushafError(Object error) => _(
    'تعذر تحميل المصحف\n$error',
    'Could not load the mushaf\n$error',
    'মুসহাফ লোড করা যায়নি\n$error',
    'مصحف لوڈ نہیں ہو سکا\n$error',
  );
  List<String> get indexTabs => [
    _('السور', 'Surahs', 'সূরা', 'سورتیں'),
    _('الأجزاء', 'Juz', 'পারা', 'پارے'),
    _('الأرباع', 'Quarters', 'রুবু', 'ارباع'),
    _('الصفحات', 'Pages', 'পৃষ্ঠা', 'صفحات'),
    _('العلامات', 'Bookmarks', 'বুকমার্ক', 'نشانیاں'),
  ];
  String get searchHint => _(
    'ابحث باسم السورة أو بالرقم',
    'Search by surah name or number',
    'সূরার নাম বা নম্বর দিয়ে খুঁজুন',
    'سورت کے نام یا نمبر سے تلاش کریں',
  );
  String get clearSearch =>
      _('مسح البحث', 'Clear search', 'খোঁজ মুছুন', 'تلاش صاف کریں');
  String get meccan => _('مكية', 'Meccan', 'মাক্কী', 'مکی');
  String get medinan => _('مدنية', 'Medinan', 'মাদানী', 'مدنی');
  String ayahCount(int count) => _(
    '${n(count)} آية',
    '${n(count)} ayat',
    '${n(count)} আয়াত',
    '${n(count)} آیات',
  );
  String juz(int juz) =>
      _('الجزء ${n(juz)}', 'Juz ${n(juz)}', 'পারা ${n(juz)}', 'پارہ ${n(juz)}');
  String hizb(int hizb) => _(
    'الحزب ${n(hizb)}',
    'Hizb ${n(hizb)}',
    'হিযব ${n(hizb)}',
    'حزب ${n(hizb)}',
  );

  /// "الحزب 3", "ربع الحزب 3", "نصف الحزب 3" or "ثلاثة أرباع الحزب 3".
  String rubTitle(int rub) {
    final h = hizb((rub - 1) ~/ 4 + 1);
    return switch ((rub - 1) % 4) {
      1 => _('ربع $h', '¼ $h', '¼ $h', 'ربع $h'),
      2 => _('نصف $h', '½ $h', '½ $h', 'نصف $h'),
      3 => _('ثلاثة أرباع $h', '¾ $h', '¾ $h', 'تین ربع $h'),
      _ => h,
    };
  }

  String page(int page) => _(
    'الصفحة ${n(page)}',
    'Page ${n(page)}',
    'পৃষ্ঠা ${n(page)}',
    'صفحہ ${n(page)}',
  );
  String ayahLabel(Surah surah, int ayah) => _(
    '${surahName(surah)} · آية ${n(ayah)}',
    '${surahName(surah)} · ayah ${n(ayah)}',
    '${surahName(surah)} · আয়াত ${n(ayah)}',
    '${surahName(surah)} · آیت ${n(ayah)}',
  );
  String get noResults =>
      _('لا توجد نتائج', 'No results', 'কোনো ফলাফল নেই', 'کوئی نتیجہ نہیں');
  String get noBookmarks => _(
    'لا توجد علامات بعد.\nاضغط مطولًا على أي آية في المصحف لإضافة علامة.',
    'No bookmarks yet.\nLong-press any ayah in the mushaf to add one.',
    'এখনো কোনো বুকমার্ক নেই।\nযোগ করতে মুসহাফে যেকোনো আয়াতে চেপে ধরুন।',
    'ابھی کوئی نشانی نہیں۔\nنشانی لگانے کے لیے مصحف میں کسی آیت کو دیر تک دبائیں۔',
  );

  // Mushaf.
  String surah(Surah s) => _(
    'سورة ${surahName(s)}',
    'Surah ${surahName(s)}',
    'সূরা ${surahName(s)}',
    'سورۃ ${surahName(s)}',
  );
  String juzAndHizb(int j, int h) => '${juz(j)} · ${hizb(h)}';
  String get previousPage =>
      _('الصفحة السابقة', 'Previous page', 'আগের পৃষ্ঠা', 'پچھلا صفحہ');
  String get nextPage =>
      _('الصفحة التالية', 'Next page', 'পরের পৃষ্ঠা', 'اگلا صفحہ');
  String get addBookmark =>
      _('إضافة علامة', 'Add bookmark', 'বুকমার্ক যোগ করুন', 'نشانی لگائیں');
  String get removeBookmark =>
      _('إزالة العلامة', 'Remove bookmark', 'বুকমার্ক সরান', 'نشانی ہٹائیں');
  String get copyAyah => _(
    'نسخ نص الآية',
    'Copy ayah text',
    'আয়াতের টেক্সট কপি করুন',
    'آیت کا متن کاپی کریں',
  );
  String loadPageError(Object error) => _(
    'تعذر تحميل الصفحة\n$error',
    'Could not load the page\n$error',
    'পৃষ্ঠা লোড করা যায়নি\n$error',
    'صفحہ لوڈ نہیں ہو سکا\n$error',
  );
  String get cancel => _('إلغاء', 'Cancel', 'বাতিল', 'منسوخ');
  String get go => _('انتقال', 'Go', 'যান', 'جائیں');
  String get pauseAutoTurn => _(
    'إيقاف التقليب التلقائي',
    'Pause automatic page turning',
    'স্বয়ংক্রিয় পৃষ্ঠা উল্টানো থামান',
    'خودکار صفحہ پلٹنا روکیں',
  );
  String get resumeAutoTurn => _(
    'تشغيل التقليب التلقائي',
    'Start automatic page turning',
    'স্বয়ংক্রিয় পৃষ্ঠা উল্টানো চালু করুন',
    'خودکار صفحہ پلٹنا شروع کریں',
  );

  // Recitation.
  String recitePage(int p) => _(
    'تسميع هذه الصفحة (${n(p)})',
    'Recite this page (${n(p)})',
    'এই পৃষ্ঠা তিলাওয়াত করুন (${n(p)})',
    'اس صفحے کی تسمیع (${n(p)})',
  );
  String reciteWholeSurah(Surah s) => _(
    'تسميع سورة ${surahName(s)} كاملة',
    'Recite all of Surah ${surahName(s)}',
    'পুরো সূরা ${surahName(s)} তিলাওয়াত করুন',
    'پوری سورۃ ${surahName(s)} کی تسمیع',
  );
  String get chooseSurahToRecite => _(
    'اختر سورة للتسميع',
    'Choose a surah to recite',
    'তিলাওয়াতের জন্য একটি সূরা বেছে নিন',
    'تسمیع کے لیے سورت چنیں',
  );
  String reciteSurahTitle(Surah s) => _(
    'تسميع سورة ${surahName(s)}',
    'Reciting Surah ${surahName(s)}',
    'সূরা ${surahName(s)} তিলাওয়াত',
    'سورۃ ${surahName(s)} کی تسمیع',
  );
  String recitePageTitle(int p) => _(
    'تسميع الصفحة ${n(p)}',
    'Reciting page ${n(p)}',
    'পৃষ্ঠা ${n(p)} তিলাওয়াত',
    'صفحہ ${n(p)} کی تسمیع',
  );
  String loadTextError(Object error) => _(
    'تعذر تحميل النص\n$error',
    'Could not load the text\n$error',
    'টেক্সট লোড করা যায়নি\n$error',
    'متن لوڈ نہیں ہو سکا\n$error',
  );
  String get hideText =>
      _('إخفاء النص', 'Hide text', 'টেক্সট লুকান', 'متن چھپائیں');
  String get showText =>
      _('إظهار النص', 'Show text', 'টেক্সট দেখান', 'متن دکھائیں');
  String get restartRecitation =>
      _('إعادة التسميع', 'Start over', 'আবার শুরু করুন', 'دوبارہ شروع کریں');
  String get stop => _('إيقاف', 'Stop', 'থামান', 'روکیں');
  String get startRecitation => _(
    'ابدأ التسميع',
    'Start reciting',
    'তিলাওয়াত শুরু করুন',
    'تسمیع شروع کریں',
  );
  String get perfectRecitation => _(
    'أحسنت! أتممت التسميع بلا أخطاء.',
    'Well done! You finished without mistakes.',
    'চমৎকার! আপনি কোনো ভুল ছাড়াই শেষ করেছেন।',
    'شاباش! آپ نے بغیر غلطی کے مکمل کیا۔',
  );
  String finishedWithMistakes(int count) => _(
    'أتممت التسميع. عدد الأخطاء: ${n(count)}',
    'Finished. Mistakes: ${n(count)}',
    'শেষ হয়েছে। ভুল: ${n(count)}',
    'مکمل ہو گیا۔ غلطیاں: ${n(count)}',
  );
  String listening(int done, int total) => _(
    'أستمع إليك… ${n(done)} من ${n(total)} كلمة',
    'Listening… ${n(done)} of ${n(total)} words',
    'শুনছি… ${n(total)} শব্দের মধ্যে ${n(done)}',
    'سن رہا ہوں… ${n(total)} میں سے ${n(done)} الفاظ',
  );
  String get pressStart => _(
    'اضغط «ابدأ التسميع» ثم اقرأ من حفظك.',
    'Press "Start reciting", then recite from memory.',
    '"তিলাওয়াত শুরু করুন" চাপুন, তারপর মুখস্থ থেকে পড়ুন।',
    '«تسمیع شروع کریں» دبائیں، پھر زبانی پڑھیں۔',
  );
  String heard(String text) =>
      _('سمعت: $text', 'Heard: $text', 'শোনা গেছে: $text', 'سنا: $text');
  String get forgotten => _('نسيتها', 'Missed', 'বাদ পড়েছে', 'رہ گیا');
  String get extraWord => _('زائدة', 'Extra', 'অতিরিক্ত', 'زائد');

  // Settings.
  String get languageTitle => _('اللغة', 'Language', 'ভাষা', 'زبان');
  String get pagesSection => _('الصفحات', 'Pages', 'পৃষ্ঠা', 'صفحات');
  String get nightMode =>
      _('الوضع الليلي', 'Night mode', 'রাতের মোড', 'نائٹ موڈ');
  String get pageColor =>
      _('اختر نمطا', 'Page color', 'পৃষ্ঠার রং', 'صفحے کا رنگ');
  String get pageColorInNightMode => _(
    'يُستخدم في الوضع النهاري',
    'Used in day mode',
    'দিনের মোডে ব্যবহৃত হয়',
    'دن کے موڈ میں استعمال ہوتا ہے',
  );
  String get twoPagesInLandscape => _(
    'صفحتان في الوضع الأفقي',
    'Two pages in landscape',
    'ল্যান্ডস্কেপে দুই পৃষ্ঠা',
    'افقی حالت میں دو صفحات',
  );
  String get playerOnTouch => _(
    'تفعيل المشغل مع اللمس',
    'Play recitation on touch',
    'স্পর্শে তিলাওয়াত শুনুন',
    'چھونے پر تلاوت سنیں',
  );
  String get autoPageTurn => _(
    'تغيير الصفحة تلقائيًا',
    'Turn pages automatically',
    'স্বয়ংক্রিয়ভাবে পৃষ্ঠা উল্টান',
    'خودکار صفحہ پلٹیں',
  );
  String autoPageEvery(int seconds) => _(
    'كل ${n(seconds)} ثانية',
    'Every ${n(seconds)} seconds',
    'প্রতি ${n(seconds)} সেকেন্ডে',
    'ہر ${n(seconds)} سیکنڈ بعد',
  );
  String get verticalScroll => _(
    'تصفح رأسي متحرك',
    'Scroll pages vertically',
    'উপর-নিচে স্ক্রল করুন',
    'صفحات اوپر نیچے اسکرول کریں',
  );
  String get tajweed =>
      _('نص التجويد', 'Tajweed colors', 'তাজবীদের রং', 'تجوید کے رنگ');
  String get tapOpensAyahMenu => _(
    'تفعيل المحتوى السريع بلمسة خفيفة',
    'Open the ayah menu with one tap',
    'এক স্পর্শে আয়াতের মেনু খুলুন',
    'ایک بار چھونے پر آیت کا مینو کھولیں',
  );
  String get keepScreenOn => _(
    'عدم قفل الشاشة عند استخدام التطبيق',
    'Keep the screen on while using the app',
    'অ্যাপ ব্যবহারের সময় স্ক্রিন চালু রাখুন',
    'ایپ استعمال کرتے وقت اسکرین بند نہ ہو',
  );
  String get thematicTafsir => _(
    'التفصيل الموضوعي',
    'Thematic tafsir',
    'বিষয়ভিত্তিক তাফসীর',
    'موضوعاتی تفسیر',
  );
  String get westernDigitsTitle => _(
    'استخدام الأرقام (123 بدلا من ١٢٣)',
    'Use 123 digits',
    '১২৩ এর বদলে 123 ব্যবহার করুন',
    '۱۲۳ کی بجائے 123 استعمال کریں',
  );
  String get followSystemFontSize => _(
    'الارتباط بحجم خط النظام',
    'Follow the system font size',
    'সিস্টেমের ফন্ট সাইজ অনুসরণ করুন',
    'سسٹم کے فونٹ سائز کی پیروی کریں',
  );
  String get hideRecitationButton => _(
    'إخفاء زر التسميع',
    'Hide the recite button',
    'তিলাওয়াত যাচাই বোতাম লুকান',
    'تسمیع کا بٹن چھپائیں',
  );
  String get showHizbMarks => _(
    'إظهار رمز الحزب داخل الصفحة',
    'Show hizb marks on the page',
    'পৃষ্ঠায় হিযবের চিহ্ন দেখান',
    'صفحے پر حزب کی علامت دکھائیں',
  );
  String get plansInAyahMenu => _(
    'عرض الخطط في العرض السريع للمحتوى',
    'Show plans in the ayah menu',
    'আয়াতের মেনুতে পরিকল্পনা দেখান',
    'آیت کے مینو میں منصوبے دکھائیں',
  );
  String get notesSection => _(
    'تعليقات على الكلمات والآيات',
    'Notes on words and ayat',
    'শব্দ ও আয়াতে নোট',
    'الفاظ اور آیات پر نوٹس',
  );
  String get advancedEditor => _(
    'استخدم محرر نصوص متقدم',
    'Use an advanced text editor',
    'উন্নত টেক্সট এডিটর ব্যবহার করুন',
    'جدید ٹیکسٹ ایڈیٹر استعمال کریں',
  );
  String get dataSection => _('البيانات', 'Data', 'ডেটা', 'ڈیٹا');
  String get backupRestore => _(
    'نسخ احتياطي/استعادة نسخة احتياطية',
    'Back up / restore',
    'ব্যাকআপ / পুনরুদ্ধার',
    'بیک اپ / بحالی',
  );
  String get comingSoon =>
      _('قريبًا', 'Coming soon', 'শীঘ্রই আসছে', 'جلد آ رہا ہے');

  // Backup.
  String get backupExplain => _(
    'النسخة الاحتياطية تحفظ الإعدادات والعلامات وآخر صفحة قرأتها. '
        'انسخها واحفظها في مكان آمن، مثل رسالة ترسلها لنفسك. '
        'ولاستعادتها الصقها في الخانة بالأسفل.',
    'The backup holds your settings, bookmarks and the last page you read. '
        'Copy it and keep it somewhere safe, such as a message to yourself. '
        'To restore it, paste it in the box below.',
    'ব্যাকআপে আপনার সেটিংস, বুকমার্ক এবং সর্বশেষ পড়া পৃষ্ঠা থাকে। '
        'এটি কপি করে নিরাপদ জায়গায় রাখুন, যেমন নিজেকে পাঠানো একটি বার্তা। '
        'পুনরুদ্ধার করতে নিচের ঘরে পেস্ট করুন।',
    'بیک اپ میں آپ کی ترتیبات، نشانیاں اور آخری پڑھا گیا صفحہ ہوتا ہے۔ '
        'اسے کاپی کر کے محفوظ جگہ رکھیں، جیسے اپنے آپ کو بھیجا گیا پیغام۔ '
        'بحال کرنے کے لیے نیچے والے خانے میں پیسٹ کریں۔',
  );
  String get copyBackup => _(
    'نسخ النسخة الاحتياطية',
    'Copy backup',
    'ব্যাকআপ কপি করুন',
    'بیک اپ کاپی کریں',
  );
  String get backupCopied => _(
    'تم نسخ النسخة الاحتياطية',
    'Backup copied',
    'ব্যাকআপ কপি হয়েছে',
    'بیک اپ کاپی ہو گیا',
  );
  String get pasteBackup => _(
    'الصق النسخة الاحتياطية هنا',
    'Paste the backup here',
    'এখানে ব্যাকআপ পেস্ট করুন',
    'بیک اپ یہاں پیسٹ کریں',
  );
  String get restore => _('استعادة', 'Restore', 'পুনরুদ্ধার', 'بحال کریں');
  String get backupRestored => _(
    'تمت استعادة النسخة الاحتياطية',
    'Backup restored',
    'ব্যাকআপ পুনরুদ্ধার হয়েছে',
    'بیک اپ بحال ہو گیا',
  );
  String get invalidBackup => _(
    'هذا النص ليس نسخة احتياطية صالحة',
    'This is not a valid backup',
    'এটি বৈধ ব্যাকআপ নয়',
    'یہ درست بیک اپ نہیں ہے',
  );
}

class StringsScope extends InheritedWidget {
  const StringsScope({super.key, required this.strings, required super.child});

  final S strings;

  @override
  bool updateShouldNotify(StringsScope old) =>
      old.strings.language != strings.language ||
      old.strings.westernDigits != strings.westernDigits;
}
