"""Build an independent reference fixture from frequent dictionary words and ctcorpus.org.
Run from the Demo directory. Neither direction uses the Swift engine under test.
"""
import hashlib
import json
import sqlite3
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

endpoint = 'https://ctcorpus.org/index.php?option=com_ajax&module=translit&method=transliterate&format=json'
database = Path('Keyboard/qırım_tatar.db')
connection = sqlite3.connect(f'file:{database}?mode=ro', uri=True)
words = [row[0] for row in connection.execute('SELECT word FROM words ORDER BY freq DESC, word') if isinstance(row[0], str) and row[0].isalpha()][:2500]

def convert(text, variant):
    data = urllib.parse.urlencode({'text': text, 'toVariant': variant}).encode()
    with urllib.request.urlopen(endpoint, data=data, timeout=60) as response:
        result = json.load(response)
    assert result['success'], result
    return result['data']['text'].split('\n')

cases = {}
for offset in range(0, len(words), 100):
    batch = words[offset:offset + 100]
    cyrillic = convert('\n'.join(batch), 'crh-cyrl')
    expected = convert('\n'.join(cyrillic), 'crh-latn')
    assert len(batch) == len(cyrillic) == len(expected)
    for source, target in zip(cyrillic, expected):
        if any('\u0400' <= c <= '\u04ff' for c in source):
            cases[source] = target
assert len(cases) >= 2000, len(cases)
root = Path('Tests/Transliteration/Tests/TransliterationTests/Resources')
(root / 'real_words.json').write_text(json.dumps(list(cases.items()), ensure_ascii=False, indent=2) + '\n')
(root / 'real_words_provenance.json').write_text(json.dumps({
    'generatedUTC': datetime.now(timezone.utc).isoformat(), 'endpoint': endpoint,
    'source': str(database), 'sourceSHA256': hashlib.sha256(database.read_bytes()).hexdigest(),
    'method': 'Top 2500 alphabetic dictionary entries by frequency; server crh-cyrl then server crh-latn; unique Cyrillic inputs. Expected output is server output, not assumed round-trip identity.',
    'count': len(cases)
}, ensure_ascii=False, indent=2) + '\n')
print(f'Generated {len(cases)} real-word reference cases')

# Apply documented capture fixes to expectations after fetching raw server output.
import subprocess
subprocess.run(["python3", "Tests/Transliteration/Tools/correct_reference_captures.py"], check=True)
