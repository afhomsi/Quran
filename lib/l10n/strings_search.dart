part of 'strings.dart';

/// Texts of the Quran search screen.
extension SearchStrings on S {
  String searchMode(SearchMode m) => switch (m) {
    SearchMode.text => _('في الآيات', 'In the ayat', 'আয়াতে', 'آیات میں'),
    SearchMode.meaning => _('في المعنى', 'In the meaning', 'অর্থে', 'معنی میں'),
  };

  String searchModeHint(SearchMode m) => switch (m) {
    SearchMode.text => _(
      'اكتب كلمة أو عبارة من القرآن',
      'Type a word or phrase of the Quran',
      'কুরআনের একটি শব্দ বা বাক্যাংশ লিখুন',
      'قرآن کا کوئی لفظ یا جملہ لکھیں',
    ),
    SearchMode.meaning => _(
      'اكتب معنى، مثل: الصبر',
      'Type a meaning, e.g. patience',
      'একটি অর্থ লিখুন, যেমন: patience',
      'کوئی معنی لکھیں، مثلاً: الصبر',
    ),
  };

  String get searchWholeWord =>
      _('كلمة كاملة', 'Whole word', 'পুরো শব্দ', 'پورا لفظ');
  String get searchAnyOrder =>
      _('كلمات متفرقة', 'Words apart', 'আলাদা শব্দ', 'الگ الگ الفاظ');
  String get searchWithTafsir =>
      _('مع التفسير', 'With tafsir', 'তাফসিরসহ', 'تفسیر کے ساتھ');
  String get searchResetOptions =>
      _('إلغاء الخيارات', 'Clear options', 'বিকল্প মুছুন', 'اختیارات ختم کریں');
  String get searchOptionsHelp => _(
    'كلمة كاملة: لا تظهر الكلمة داخل كلمة أطول. كلمات متفرقة: تكفي الكلمات في أي مكان من الآية وبأي ترتيب. مع التفسير: تظهر أيضاً الآيات التي يذكر تفسير الجلالين الكلمة في شرحها.',
    'Whole word: the word is not found inside longer words. Words apart: the words may be anywhere in the ayah, in any order. With tafsir: also shows ayat whose explanation in Tafsir al-Jalalayn has the words.',
    'পুরো শব্দ: লম্বা শব্দের ভিতরে খোঁজে না। আলাদা শব্দ: শব্দগুলো আয়াতের যেকোনো জায়গায়, যেকোনো ক্রমে। তাফসিরসহ: তাফসিরে জালালাইনের ব্যাখ্যায় শব্দগুলো থাকলে সেই আয়াতও দেখায়।',
    'پورا لفظ: لمبے الفاظ کے اندر نہیں ڈھونڈتا۔ الگ الگ الفاظ: الفاظ آیت میں کہیں بھی، کسی بھی ترتیب میں۔ تفسیر کے ساتھ: وہ آیات بھی جن کی تفسیر جلالین میں یہ الفاظ ہوں۔',
  );
  String get searchMeaningHelp => _(
    'يبحث في شرح تفسير الجلالين. اكتب بالإنجليزية للبحث في ترجمة Pickthall.',
    'Searches the explanation in Tafsir al-Jalalayn. Type in English to search Pickthall\'s translation.',
    'তাফসিরে জালালাইনের ব্যাখ্যায় খোঁজে। Pickthall-এর অনুবাদে খুঁজতে ইংরেজিতে লিখুন।',
    'تفسیر جلالین کی شرح میں ڈھونڈتا ہے۔ Pickthall کے ترجمے میں ڈھونڈنے کے لیے انگریزی میں لکھیں۔',
  );
  String get searchLoading => _(
    'جارٍ تجهيز البحث…',
    'Getting search ready…',
    'খোঁজ প্রস্তুত হচ্ছে…',
    'تلاش تیار ہو رہی ہے…',
  );
  String hitSource(HitSource s) => switch (s) {
    HitSource.ayah => '',
    HitSource.tafsir => _(
      'من تفسير الجلالين',
      'From Tafsir al-Jalalayn',
      'তাফসিরে জালালাইন থেকে',
      'تفسیر جلالین سے',
    ),
    HitSource.translation => _(
      'من ترجمة Pickthall',
      'From Pickthall\'s translation',
      'Pickthall-এর অনুবাদ থেকে',
      'Pickthall کے ترجمے سے',
    ),
  };
  String searchCount(int count) => _(
    '${n(count)} آية',
    '${n(count)} ayat',
    '${n(count)}টি আয়াত',
    '${n(count)} آیات',
  );
}
