"""Correct four missing captures and four approved exception/reference fixes independently of Swift; verify fixtures."""
import copy
import json
import re
from pathlib import Path
rules_path = Path('Keyboard/TransliterationRules.json')
data = json.loads(rules_path.read_text())
original = copy.deepcopy(data)
indices = [194, 197, 208, 211]
for i in indices:
    original['rules'][i][1] = original['rules'][i][1][:-2] + '$2'
    data['rules'][i][1] = data['rules'][i][1][:-2] + '$1'

def engine(dataset):
    steps = [(re.compile(p, re.M), r) if p != 'all_other_letters' else (None, None) for p,r in dataset['rules']]
    fallback = dict(dataset['fallback'])
    def convert(text):
        for a,b in dataset['exceptions']: text = text.replace(a,b)
        parts = re.split('([' + dataset['lettersCyrl'] + ']+)', text)
        joined = '\n'.join(parts[1::2])
        for regex, replacement in steps:
            if regex is None:
                joined = ''.join(fallback.get(c,c) for c in joined)
            else:
                def replace(match):
                    return re.sub(r'\$(\d+)', lambda g: (match.group(int(g[1])) or '') if int(g[1]) <= regex.groups else '', replacement)
                joined = regex.sub(replace, joined)
        if parts[1::2]: parts[1::2] = joined.split('\n')
        return ''.join(parts)
    return convert
old, new = engine(original), engine(data)
root = Path('Tests/Transliteration/Tests/TransliterationTests/Resources')
changes=[]
for name in ['parity.json', 'real_words.json']:
    path=root/name
    cases=json.loads(path.read_text())
    for pair in cases:
        if pair[0] == 'селямет' and pair[1] == 'selâmyet':
            changes.append({'fixture':name,'source':pair[0],'upstream':'selâmyet','corrected':'selâmet'})
            pair[1] = 'selâmet'
            continue
        corrected=new(pair[0])
        if corrected!=old(pair[0]):
            changes.append({'fixture':name,'source':pair[0],'upstream':old(pair[0]),'corrected':corrected})
            pair[1]=corrected
    mismatches=[s for s,t in cases if new(s)!=t]
    assert not mismatches, mismatches[:10]
    path.write_text(json.dumps(cases,ensure_ascii=False,indent=2)+'\n')
rules_path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
(root/'capture_corrections.json').write_text(json.dumps(changes,ensure_ascii=False,indent=2)+'\n')
print('Corrected reference cases:',len(changes))
