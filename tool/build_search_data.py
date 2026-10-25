"""Builds the books the Quran search reads from, so search works offline.

  assets/search/jalalayn.json.gz  Tafsir al-Jalalayn (public domain), from
                                   github.com/spa5k/tafsir_api
  assets/search/pickthall.json.gz Pickthall's English translation (1930,
                                   public domain), from
                                   github.com/fawazahmed0/quran-api

Each file is a list of surahs, each a list of ayah texts.

Run: python3 tool/build_search_data.py
"""
import gzip
import json
import urllib.request

AYAT = [7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99,
        128, 111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34,
        30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29,
        18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12,
        30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25,
        22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9,
        5, 4, 7, 3, 6, 3, 5, 4, 5, 6]


def get(url):
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.load(r)


def jalalayn():
    base = 'https://raw.githubusercontent.com/spa5k/tafsir_api/main/tafsir/ar-tafsir-al-jalalayn'
    out = []
    for s, count in enumerate(AYAT, 1):
        texts = [''] * count
        for item in get(f'{base}/{s}.json'):
            texts[item['ayah'] - 1] = item['text'].strip()
        out.append(texts)
    return out


def pickthall():
    url = 'https://raw.githubusercontent.com/fawazahmed0/quran-api/1/editions/eng-mohammedmarmadu.json'
    out = [[''] * n for n in AYAT]
    for item in get(url)['quran']:
        out[item['chapter'] - 1][item['verse'] - 1] = item['text'].strip()
    return out


def write(name, data):
    assert sum(len(s) for s in data) == 6236
    raw = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    with open(f'assets/search/{name}.json.gz', 'wb') as f:
        f.write(gzip.compress(raw.encode(), mtime=0))


write('jalalayn', jalalayn())
write('pickthall', pickthall())
