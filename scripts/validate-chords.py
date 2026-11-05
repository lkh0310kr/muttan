#!/usr/bin/env python3
"""Validate the bundled chord catalog without external dependencies."""
import json
from pathlib import Path

catalog = json.loads((Path(__file__).resolve().parents[1] / 'muttan/Features/Chords/chords.json').read_text())
expected = {'C', 'D', 'E', 'F', 'G', 'A', 'Am', 'Dm', 'Em', 'Bm', 'A7', 'D7'}
assert {chord['symbol'] for chord in catalog} == expected
assert len(catalog) == len(expected)
tuning = [40, 45, 50, 55, 59, 64]
intervals = {'major': {0, 4, 7}, 'minor': {0, 3, 7}, 'dominant7': {0, 4, 7, 10}}
ids = set()
for chord in catalog:
    assert chord['id'] not in ids
    ids.add(chord['id'])
    assert 0 <= chord['root'] < 12
    assert len(chord['voicings']) == 2
    assert chord['voicings'][0]['frets'] != chord['voicings'][1]['frets']
    target = {(chord['root'] + interval) % 12 for interval in intervals[chord['quality']]}
    for voicing in chord['voicings']:
        assert voicing['id'] not in ids
        ids.add(voicing['id'])
        frets, fingers = voicing['frets'], voicing['fingers']
        assert len(frets) == len(fingers) == 6
        for fret, finger in zip(frets, fingers):
            assert (fret is None and finger is None) or (fret == 0 and finger == 0) or (isinstance(fret, int) and 1 <= fret <= 24 and isinstance(finger, int) and 1 <= finger <= 4), voicing['id']
        pitches = {(note + fret) % 12 for note, fret in zip(tuning, frets) if fret is not None}
        assert pitches == target, (voicing['id'], pitches, target)
        positive = [fret for fret in frets if fret is not None and fret > 0]
        assert max(positive) - min(positive) < 5
        for barre in voicing['barres']:
            assert 1 <= barre['toString'] < barre['fromString'] <= 6
            assert 1 <= barre['finger'] <= 4
            assert barre['fret'] in positive
            for string in range(barre['toString'], barre['fromString'] + 1):
                fret, finger = frets[6 - string], fingers[6 - string]
                assert fret is not None and fret >= barre['fret']
                assert fret != barre['fret'] or finger == barre['finger']
        for finger in range(1, 5):
            indices = [i for i, value in enumerate(fingers) if value == finger]
            if len(indices) > 1:
                assert len({frets[i] for i in indices}) == 1
                assert any(barre['finger'] == finger and barre['fromString'] >= 6 - min(indices) and barre['toString'] <= 6 - max(indices) for barre in voicing['barres'])
print(f'Validated {len(catalog)} chords and {sum(len(c["voicings"]) for c in catalog)} voicings.')
