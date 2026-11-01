part of 'strings.dart';

/// Texts of today's wird, the daily review and the hifz map.
extension ReviewStrings on S {
  String get todayWird =>
      _('وردي اليوم', "Today's wird", 'আজকের ওয়ির্দ', 'آج کا ورد');
  String get todayReview =>
      _('مراجعة اليوم', "Today's review", 'আজকের রিভিউ', 'آج کی دہرائی');
  String get startReview =>
      _('ابدأ المراجعة', 'Start the review', 'রিভিউ শুরু', 'دہرائی شروع کریں');
  String get noReviewYet => _(
    'سمّع أي صفحة من حفظك، وسيذكّرك التطبيق بمراجعتها قبل أن تنساها.',
    'Recite any page you know by heart, and the app will remind you to review it before you forget it.',
    'মুখস্থ যেকোনো পৃষ্ঠা শোনান, ভুলে যাওয়ার আগে অ্যাপ আপনাকে রিভিউ করতে মনে করিয়ে দেবে।',
    'اپنے حفظ کا کوئی بھی صفحہ سنائیں، بھولنے سے پہلے ایپ آپ کو دہرانے کی یاد دلائے گی۔',
  );
  String get reviewDone => _(
    'لا مراجعة عليك اليوم، أحسنت. بارك الله في حفظك.',
    'No review due today. Well done!',
    'আজ কোনো রিভিউ বাকি নেই। চমৎকার!',
    'آج کوئی دہرائی باقی نہیں۔ شاباش!',
  );
  String moreDue(int count) => _(
    'وبعدها ${n(count)} صفحة أخرى تنتظر المراجعة',
    'and ${n(count)} more pages are waiting',
    'আরও ${n(count)} পৃষ্ঠা অপেক্ষায়',
    'اور ${n(count)} صفحے مزید منتظر ہیں',
  );
  String get newRecitation =>
      _('التسميع الجديد', 'New recitation', 'নতুন শোনানো', 'نیا سنانا');
  String get makeRecitePlan => _(
    'أنشئ خطة تسميع',
    'Make a recitation plan',
    'শোনানোর পরিকল্পনা করুন',
    'سنانے کا منصوبہ بنائیں',
  );
  String get recitePlanDone => _(
    'أتممت خطة التسميع، أحسنت.',
    'Recitation plan complete. Well done!',
    'শোনানোর পরিকল্পনা শেষ। চমৎকার!',
    'سنانے کا منصوبہ مکمل۔ شاباش!',
  );
  String get hifzMap =>
      _('خريطة حفظي', 'My hifz map', 'আমার হিফজ মানচিত্র', 'میرے حفظ کا نقشہ');
  String get hifzMapHelp => _(
    'كل مربع صفحة من المصحف، لونها من آخر تسميع لها. اضغط على صفحة لتفتحها.',
    'Each square is a mushaf page, coloured by how you last recited it. Tap a page to open it.',
    'প্রতিটি ঘর মুসহাফের একটি পৃষ্ঠা, শেষবার কেমন শুনিয়েছেন সেই রঙে। খুলতে পৃষ্ঠায় চাপুন।',
    'ہر خانہ مصحف کا ایک صفحہ ہے، آخری بار سنانے کے مطابق رنگین۔ کھولنے کے لیے صفحے پر دبائیں۔',
  );
  String strengthName(int index) => switch (index) {
    1 => _('ضعيف', 'Weak', 'দুর্বল', 'کمزور'),
    2 => _('متوسط', 'Medium', 'মাঝারি', 'درمیانہ'),
    3 => _('قوي', 'Strong', 'মজবুত', 'مضبوط'),
    _ => _('لم يُسمَّع', 'Not recited', 'শোনানো হয়নি', 'نہیں سنایا'),
  };
  String strengthCount(int index, int count) =>
      '${strengthName(index)} ${n(count)}';
  String get openOnToday => _(
    'افتح التطبيق على «وردي اليوم» إذا كان عليك مراجعة',
    "Open the app on today's wird when a review is due",
    'রিভিউ বাকি থাকলে অ্যাপ «আজকের ওয়ির্দ»-এ খুলুন',
    'دہرائی باقی ہو تو ایپ «آج کا ورد» پر کھولیں',
  );
  String lastRecitedDaysAgo(int days) => switch (days) {
    0 => _('سُمّعت اليوم', 'Recited today', 'আজ শোনানো', 'آج سنایا'),
    1 => _('سُمّعت أمس', 'Recited yesterday', 'গতকাল শোনানো', 'کل سنایا'),
    _ => _(
      'آخر تسميع قبل ${n(days)} يوم',
      'Last recited ${n(days)} days ago',
      '${n(days)} দিন আগে শোনানো',
      '${n(days)} دن پہلے سنایا',
    ),
  };
}
