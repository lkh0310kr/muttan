#!/usr/bin/env python3
"""Validate the bundled chord catalog without external dependencies."""
import json
from pathlib import Path

catalog = json.loads((Path(__file__).resolve().parents[1] / 'muttan/Features/Chords/chords.json').read_text())
qualities = {
    'major': {0, 4, 7}, 'minor': {0, 3, 7}, 'dominant7': {0, 4, 7, 10},
    'major7': {0, 4, 7, 11}, 'minor7': {0, 3, 7, 10},
    'sus2': {0, 2, 7}, 'sus4': {0, 5, 7}, 'major6': {0, 4, 7, 9},
    'minor6': {0, 3, 7, 9}, 'add9': {0, 2, 4, 7}, 'dominant9': {0, 2, 4, 7, 10},
    'diminished': {0, 3, 6}, 'diminished7': {0, 3, 6, 9},
    'halfDiminished7': {0, 3, 6, 10}, 'augmented': {0, 4, 8},
}
expected = {(root, quality) for root in range(12) for quality in qualities}
assert {(c['root'], c['quality']) for c in catalog} == expected
assert len(catalog) == len(expected)
assert len({c['symbol'] for c in catalog}) == len(expected)
tuning = [40, 45, 50, 55, 59, 64]
intervals = qualities
ids = set()
for chord in catalog:
    assert chord['id'] not in ids
    ids.add(chord['id'])
    assert 0 <= chord['root'] < 12
    assert len(chord['voicings']) >= 1
    assert len({tuple(v['frets']) for v in chord['voicings']}) == len(chord['voicings'])
    target = {(chord['root'] + interval) % 12 for interval in intervals[chord['quality']]}
    for voicing in chord['voicings']:
        assert voicing['id'] not in ids
        ids.add(voicing['id'])
        frets, fingers = voicing['frets'], voicing['fingers']
        assert len(frets) == len(fingers) == 6
        for fret, finger in zip(frets, fingers):
            assert (fret is None and finger is None) or (fret == 0 and finger == 0) or (isinstance(fret, int) and 1 <= fret <= 24 and isinstance(finger, int) and 1 <= finger <= 4), voicing['id']
        pitches = {(note + fret) % 12 for note, fret in zip(tuning, frets) if fret is not None}
        required = target - {(chord['root'] + 7) % 12} if chord['quality'] == 'dominant7' else target
        assert required <= pitches <= target, (voicing['id'], pitches, target)
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
