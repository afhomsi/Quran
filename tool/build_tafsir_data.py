"""Builds the tafsir kept in the app, so it reads without internet.

  assets/tafsir/jami_wajiz.json.gz  Al-Jami' al-Wajiz fi Tafsir Ay al-Kitab
                                    al-'Aziz, Dr. Ayman Fatih Al 'Amer,
                                    CC BY-ND 4.0, from
                                    github.com/yamanamr/quran-tafsir-jami-wajiz

The licence lets the text be shared, also commercially, as long as the
author is named and the text is not changed, so it is kept word for word.
The file is a list of surahs, each a list of ayah texts.

Run: python3 tool/build_tafsir_data.py
"""
import gzip
import json
import urllib.request

BASE = 'https://raw.githubusercontent.com/yamanamr/quran-tafsir-jami-wajiz/main'
PARTS = ['001-020', '021-060', '061-114']


def get(url):
    with urllib.request.urlopen(url, timeout=120) as r:
        return json.load(r)


def jami_wajiz():
    records = []
    for part in PARTS:
        records += get(f'{BASE}/ayah_tafsir_db_surah_{part}.json')
    counts = {}
    for r in records:
        s = int(r['surah_number'])
        counts[s] = max(counts.get(s, 0), int(r['ayah_number']))
    out = [[''] * counts[s] for s in range(1, 115)]
    for r in records:
        out[int(r['surah_number']) - 1][int(r['ayah_number']) - 1] = \
            r['tafsir_text'].strip()
    assert all(text for surah in out for text in surah)
    return out


def write(name, data):
    assert sum(len(s) for s in data) == 6236
    raw = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    with open(f'assets/tafsir/{name}.json.gz', 'wb') as f:
        f.write(gzip.compress(raw.encode(), mtime=0))


write('jami_wajiz', jami_wajiz())
