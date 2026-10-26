part of 'strings.dart';

/// Texts of choosing how strictly to check a recitation, and of the
/// mistakes report at its end.
extension ModeStrings on S {
  String get chooseRecitationMode => _(
    'كيف تريد التسميع؟',
    'How do you want to recite?',
    'কীভাবে তিলাওয়াত যাচাই করবেন?',
    'آپ کیسے تسمیع کرنا چاہتے ہیں؟',
  );
  String get strictMode => _(
    'دقيق: الكلمات والحركات',
    'Strict: words and harakat',
    'কঠোর: শব্দ ও হরকত',
    'سخت: الفاظ اور حرکات',
  );
  String get strictModeHint => _(
    'خطأ الكلمة أو الآية بالأحمر، وخطأ الحركة بالبرتقالي.',
    'A wrong word or ayah shows in red, a wrong haraka in orange.',
    'ভুল শব্দ বা আয়াত লাল, ভুল হরকত কমলা রঙে দেখাবে।',
    'غلط لفظ یا آیت سرخ، اور غلط حرکت نارنجی میں دکھے گی۔',
  );
  String get strictNeedsModel => _(
    'الحركات تُفحص فقط مع نموذج التسميع بدون إنترنت. بدونه تُفحص الكلمات فقط.',
    'Harakat are checked only with the offline recitation model. Without it, only words are checked.',
    'হরকত শুধু অফলাইন তিলাওয়াত মডেলে যাচাই হয়। মডেল ছাড়া শুধু শব্দ যাচাই হবে।',
    'حرکات صرف آف لائن تلاوت ماڈل سے جانچی جاتی ہیں۔ اس کے بغیر صرف الفاظ جانچے جائیں گے۔',
  );
  String get lenientMode => _(
    'مخفف: الكلمات فقط',
    'Lenient: words only',
    'সহজ: শুধু শব্দ',
    'نرم: صرف الفاظ',
  );
  String get lenientModeHint => _(
    'لا ينظر إلى الحركات والتجويد، ويتسامح في الأخطاء الصغيرة والكلمات الزائدة.',
    'Ignores harakat and tajweed, and forgives small slips and extra words.',
    'হরকত ও তাজবীদ দেখে না, ছোট ভুল ও অতিরিক্ত শব্দ ক্ষমা করে।',
    'حرکات اور تجوید کو نہیں دیکھتا، چھوٹی غلطیاں اور زائد الفاظ معاف کرتا ہے۔',
  );
  String get rememberRecitationMode => _(
    'تذكّر اختياري ولا تسألني مرة أخرى',
    "Remember my choice and don't ask again",
    'আমার পছন্দ মনে রাখুন, আর জিজ্ঞেস করবেন না',
    'میرا انتخاب یاد رکھیں اور دوبارہ نہ پوچھیں',
  );
  String get askRecitationMode => _(
    'اسألني عن طريقة التسميع قبل كل تسميع',
    'Ask how to check before each recitation',
    'প্রতিবার তিলাওয়াতের আগে যাচাইয়ের ধরন জিজ্ঞেস করুন',
    'ہر تسمیع سے پہلے طریقہ پوچھیں',
  );
  String get recitationModeTitle => _(
    'طريقة التسميع',
    'Recitation check',
    'তিলাওয়াত যাচাইয়ের ধরন',
    'تسمیع کا طریقہ',
  );
  String get strictShort => _('دقيق', 'Strict', 'কঠোর', 'سخت');
  String get lenientShort => _('مخفف', 'Lenient', 'সহজ', 'نرم');

  // The report at the end.
  String get mistakesReport => _(
    'تقرير الأخطاء',
    'Mistakes report',
    'ভুলের প্রতিবেদন',
    'غلطیوں کی رپورٹ',
  );
  String get wordMistakes => _(
    'أخطاء الكلمات والآيات',
    'Word and ayah mistakes',
    'শব্দ ও আয়াতের ভুল',
    'الفاظ اور آیات کی غلطیاں',
  );
  String get harakatMistakes =>
      _('أخطاء الحركات', 'Harakat mistakes', 'হরকতের ভুল', 'حرکات کی غلطیاں');
  String get noMistakesOfKind => _('لا يوجد', 'None', 'নেই', 'کوئی نہیں');
  String get harakatNotChecked => _(
    'لم تُفحص الحركات: تحتاج نموذج التسميع بدون إنترنت.',
    'Harakat were not checked: they need the offline recitation model.',
    'হরকত যাচাই হয়নি: অফলাইন তিলাওয়াত মডেল দরকার।',
    'حرکات نہیں جانچی گئیں: آف لائن تلاوت ماڈل درکار ہے۔',
  );
  String get harakatOff => _(
    'الوضع المخفف: لم تُفحص الحركات.',
    'Lenient mode: harakat were not checked.',
    'সহজ মোড: হরকত যাচাই হয়নি।',
    'نرم طریقہ: حرکات نہیں جانچی گئیں۔',
  );
  String reportSummary(int words, int harakat) => _(
    'أخطاء الكلمات: ${n(words)} · أخطاء الحركات: ${n(harakat)}',
    'Word mistakes: ${n(words)} · Harakat mistakes: ${n(harakat)}',
    'শব্দের ভুল: ${n(words)} · হরকতের ভুল: ${n(harakat)}',
    'الفاظ کی غلطیاں: ${n(words)} · حرکات کی غلطیاں: ${n(harakat)}',
  );
  String finishedWithKinds(int words, int harakat) => _(
    'أتممت التسميع. أخطاء الكلمات: ${n(words)}، الحركات: ${n(harakat)}',
    'Finished. Word mistakes: ${n(words)}, harakat: ${n(harakat)}',
    'শেষ। শব্দের ভুল: ${n(words)}, হরকত: ${n(harakat)}',
    'مکمل۔ الفاظ کی غلطیاں: ${n(words)}، حرکات: ${n(harakat)}',
  );
  String get wrongHarakatNote => _('حركة', 'Haraka', 'হরকত', 'حرکت');
}
