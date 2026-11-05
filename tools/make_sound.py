"""Generates every sound and tune in assets/custom/sound/. Run from the project root:
python tools/make_sound.py    Needs numpy. Everything is original and made only from
code, so there is nothing to license. Tunes loop: the WAV's own loop marker tells
Godot where."""
import struct
import wave
from pathlib import Path
import numpy as np

OUT = Path("assets/custom/sound")
RATE = 32000
A4 = 440.0
SEMITONES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(note):
    """'C4', 'F#3' or 'Bb4' to a frequency."""
    letter, rest = note[0], note[1:]
    semitone = SEMITONES[letter]
    if rest[0] in "#b":
        semitone += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return A4 * 2 ** ((semitone + (int(rest) + 1) * 12 - 69) / 12)


def times(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def envelope(n, attack=0.004, decay=0.08, sustain=0.6, release=0.03):
    """Attack, decay and sustain, ending in a short release, as a curve of n samples."""
    a, d, r = int(attack * RATE), int(decay * RATE), int(release * RATE)
    a, r = min(a, n // 4), min(r, n // 3)
    d = min(d, max(n - a - r, 0))
    s = max(n - a - d - r, 0)
    return np.concatenate([
        np.linspace(0, 1, a, endpoint=False),
        np.linspace(1, sustain, d, endpoint=False),
        np.full(s, sustain),
        np.linspace(sustain, 0, r),
    ])[:n]


def harmonics(freq, seconds, amplitude_of, vibrato=0.0):
    """A wave built from its harmonics, stopping below half the sample rate so no
    harsh aliasing gets in. freq may be a number or a curve."""
    t = times(seconds)
    freqs = np.full(t.size, float(freq)) if np.isscalar(freq) else np.asarray(freq, dtype=float)[:t.size]
    if vibrato:
        freqs = freqs * (1 + 0.004 * np.sin(2 * np.pi * vibrato * t))
    phase = 2 * np.pi * np.cumsum(freqs) / RATE
    top = freqs.max()
    out = np.zeros(t.size)
    k = 1
    while k * top < RATE * 0.45 and k < 40:
        out += amplitude_of(k) * np.sin(k * phase)
        k += 1
    return out


def pulse(freq, seconds, duty=0.25, vibrato=0.0):
    return harmonics(freq, seconds, lambda k: 2 / (k * np.pi) * np.sin(k * np.pi * duty) * 0.9, vibrato)


def triangle(freq, seconds):
    return harmonics(freq, seconds,
                     lambda k: 0.0 if k % 2 == 0 else (8 / np.pi ** 2) * (-1) ** ((k - 1) // 2) / k ** 2)


def sine(freq, seconds):
    return harmonics(freq, seconds, lambda k: 1.0 if k == 1 else 0.0)


def noise(seconds, seed=1, color=0.0):
    """White noise, darkened by `color` (0 to 0.99)."""
    source = np.random.default_rng(seed).uniform(-1, 1, int(seconds * RATE))
    if color <= 0:
        return source
    out = np.zeros(source.size)
    held = 0.0
    for i, value in enumerate(source):
        held = held * color + value * (1 - color)
        out[i] = held
    return out / max(np.abs(out).max(), 1e-6)


def glide(start, end, seconds):
    return np.geomspace(start, end, int(seconds * RATE))


def decay_curve(n, speed):
    return np.exp(-speed * np.arange(n) / RATE)


def mix_at(out, sound, start):
    start = int(start * RATE)
    end = min(start + sound.size, out.size)
    if end > start:
        out[start:end] += sound[:end - start]


def write_wav(name, samples, loop_end=None):
    """Writes 16-bit mono. A loop_end adds the 'smpl' chunk Godot reads as a loop."""
    peak = np.abs(samples).max()
    if peak > 0.98:
        samples = samples * (0.98 / peak)
    data = (samples * 32767).astype("<i2").tobytes()
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(data)
    if loop_end is not None:
        smpl = struct.pack("<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, loop_end - 1, 0, 0)
        raw = path.read_bytes() + b"smpl" + struct.pack("<I", len(smpl)) + smpl
        path.write_bytes(raw[:4] + struct.pack("<I", len(raw) - 8) + raw[8:])
    print(f"{path}  {samples.size / RATE:.2f}s  peak {peak:.2f}")


def sequence(notes, step, voice, volume=1.0):
    """notes is a list of (note, length in steps) played one after another."""
    total = sum(length for _, length in notes) * step
    out = np.zeros(int(total * RATE) + RATE)
    at = 0.0
    for note, length in notes:
        seconds = length * step
        if note != "-":
            mix_at(out, voice(hz(note), seconds), at)
        at += seconds
    return out[:int(total * RATE)] * volume


# --- Sound effects ----------------------------------------------------------

def sfx():
    def blip(freq, seconds, duty=0.5, speed=30):
        return pulse(freq, seconds, duty) * decay_curve(int(seconds * RATE), speed)

    def tones(pattern, step, voice):
        out = np.zeros(int((len(pattern) * step + 1.1) * RATE))
        last = 0
        for i, note in enumerate(pattern):
            sound = voice(hz(note))
            mix_at(out, sound, i * step)
            last = max(last, int(i * step * RATE) + sound.size)
        return out[:last]

    write_wav("click", 0.35 * blip(880, 0.05, 0.25, 60))
    write_wav("hover", 0.14 * blip(1320, 0.03, 0.5, 90))
    write_wav("back", 0.3 * pulse(glide(660, 440, 0.07), 0.07, 0.25) * decay_curve(int(0.07 * RATE), 30))

    rattle = np.zeros(int(0.7 * RATE))
    gaps = np.cumsum(np.linspace(0.04, 0.11, 8))
    for i, at in enumerate(gaps):
        length = int(0.03 * RATE)
        knock = noise(0.03, 10 + i, 0.3) * decay_curve(length, 120)
        tone = triangle(300 + 60 * (i % 3), 0.03) * decay_curve(length, 100)
        mix_at(rattle, 0.5 * knock + 0.3 * tone, at - 0.04)
    write_wav("dice_roll", rattle * 0.8)
    write_wav("dice_land", 0.5 * tones(["G5", "D6"], 0.06, lambda f: blip(f, 0.14, 0.25, 22)))

    thud = 0.5 * noise(0.06, 3, 0.7) * decay_curve(int(0.06 * RATE), 70)
    write_wav("step", thud + 0.25 * triangle(glide(170, 90, 0.06), 0.06) * decay_curve(int(0.06 * RATE), 60))

    write_wav("coin", 0.4 * tones(["B5", "E6"], 0.07, lambda f: blip(f, 0.24, 0.5, 16)))
    write_wav("coin_loss", 0.35 * tones(["E5", "B4", "G4"], 0.08, lambda f: blip(f, 0.16, 0.25, 22)))
    write_wav("item", 0.35 * tones(["C5", "E5", "G5", "C6"], 0.06, lambda f: blip(f, 0.2, 0.25, 16)))
    write_wav("heal", 0.3 * tones(["C5", "G5", "E5", "C6", "G5", "E6"], 0.07,
                                  lambda f: sine(f, 0.3) * decay_curve(int(0.3 * RATE), 9)))

    swirl = sine(glide(400, 1800, 0.5), 0.5) * envelope(int(0.5 * RATE), 0.03, 0.2, 0.6, 0.2)
    swirl *= 1 + 0.5 * np.sin(2 * np.pi * 14 * times(0.5))
    write_wav("magic", swirl * 0.22)

    length = int(0.32 * RATE)
    trap = pulse(glide(400, 70, 0.32), 0.32, 0.25) * decay_curve(length, 5)
    write_wav("trap", 0.34 * trap + 0.24 * noise(0.32, 5, 0.5) * decay_curve(length, 16))

    length = int(0.14 * RATE)
    hit = 0.65 * noise(0.14, 6, 0.3) * decay_curve(length, 34)
    hit = hit + 0.5 * triangle(glide(240, 60, 0.14), 0.14) * decay_curve(length, 22)
    write_wav("hit", hit)
    write_wav("miss", 0.34 * noise(0.2, 7, 0.86) * envelope(int(0.2 * RATE), 0.05, 0.1, 0.4, 0.07))
    ring = 0.3 * tones(["A5", "A6"], 0.03, lambda f: blip(f, 0.12, 0.5, 30))
    clash = np.zeros(ring.size + length)
    mix_at(clash, ring, 0.0)
    mix_at(clash, hit * 0.5, 0.0)
    write_wav("counter", clash)
    write_wav("flee", 0.3 * pulse(glide(300, 900, 0.26), 0.26, 0.25) * envelope(int(0.26 * RATE), 0.01, 0.1, 0.6, 0.1))
    write_wav("whoosh", 0.3 * noise(0.34, 8, 0.8) * envelope(int(0.34 * RATE), 0.12, 0.1, 0.6, 0.14))

    sting = tones(["A3", "A3", "C4", "E4", "A4"], 0.08,
                  lambda f: pulse(f, 0.3, 0.25) * decay_curve(int(0.3 * RATE), 7))
    low = tones(["A2", "A2", "A2", "E3", "A3"], 0.08,
                lambda f: triangle(f, 0.3) * decay_curve(int(0.3 * RATE), 6))
    write_wav("battle_start", 0.36 * sting + 0.26 * low)

    victory = np.zeros(int(1.5 * RATE))
    mix_at(victory, tones(["C5", "C5", "C5", "G5", "E5", "G5"], 0.11,
                          lambda f: pulse(f, 0.2, 0.25) * envelope(int(0.2 * RATE), decay=0.1, sustain=0.5, release=0.05)), 0)
    mix_at(victory, pulse(hz("C6"), 0.7, 0.25, 6) * envelope(int(0.7 * RATE), decay=0.1, sustain=0.6, release=0.3), 0.66)
    write_wav("victory", 0.3 * victory)

    write_wav("defeat", 0.3 * tones(["A4", "F4", "D4", "C#4", "A3"], 0.2,
                                    lambda f: pulse(f, 0.5, 0.5) * envelope(int(0.5 * RATE), decay=0.15, sustain=0.4, release=0.2)))
    write_wav("level_up", 0.3 * tones(["G4", "C5", "E5", "G5", "E5", "G5", "C6"], 0.075,
                                      lambda f: pulse(f, 0.3, 0.25) * decay_curve(int(0.3 * RATE), 8)))
    write_wav("town", 0.3 * tones(["E4", "G4", "C5", "E5", "G5"], 0.09,
                                  lambda f: pulse(f, 0.5, 0.25) * decay_curve(int(0.5 * RATE), 6)))
    write_wav("week", 0.3 * tones(["G5", "C5"], 0.32,
                                  lambda f: (sine(f, 1.0) + 0.5 * sine(f * 2.76, 1.0)) * decay_curve(RATE, 5)))

    drone = np.zeros(int(1.4 * RATE))
    for note in ("C3", "F#3", "C4"):
        drone += pulse(hz(note), 1.4, 0.5, 5) * envelope(drone.size, 0.05, 0.3, 0.5, 0.7)
    write_wav("crown", 0.15 * drone)

    fanfare = np.zeros(int(3.6 * RATE))
    beat = 0.14
    for at, note, length in [(0, "C4", 1), (1, "C4", 1), (2, "C4", 1), (3, "G4", 3), (6, "E4", 2),
                             (8, "G4", 2), (10, "C5", 3), (13, "B4", 1), (14, "C5", 1), (15, "E5", 2),
                             (17, "G5", 7)]:
        seconds = length * beat + 0.08
        n = int(seconds * RATE)
        shape = envelope(n, decay=0.1, sustain=0.65, release=0.1)
        mix_at(fanfare, pulse(hz(note), seconds, 0.25, 6 if length > 3 else 0) * shape, at * beat)
        mix_at(fanfare, 0.6 * pulse(hz(note) / 2, seconds, 0.5) * shape, at * beat)
    for at, note in [(0, "C3"), (6, "G3"), (10, "C3"), (17, "C3")]:
        mix_at(fanfare, triangle(hz(note), 0.9) * envelope(int(0.9 * RATE), decay=0.3, sustain=0.5, release=0.2), at * beat)
    write_wav("fanfare", 0.26 * fanfare)


# --- Tunes ------------------------------------------------------------------

CHORDS = {
    "C": ["C", "E", "G"], "F": ["F", "A", "C"], "G": ["G", "B", "D"], "Am": ["A", "C", "E"],
    "Em": ["E", "G", "B"], "Dm": ["D", "F", "A"], "Bb": ["Bb", "D", "F"], "Gm": ["G", "Bb", "D"],
    "E": ["E", "G#", "B"],
}


def parse(text):
    """'C5 . E5 G5 - .' Each word is one step. '.' holds the note, '-' is a rest, and
    '|' only marks the bars, for reading."""
    notes = []
    for word in text.replace("|", " ").split():
        if word == "." and notes:
            notes[-1] = (notes[-1][0], notes[-1][1] + 1)
        else:
            notes.append(("-" if word in "-." else word, 1))
    return notes


def lead_voice(duty, vibrato=5.0):
    def voice(freq, seconds):
        n = int(seconds * RATE)
        return pulse(freq, seconds, duty, vibrato if seconds > 0.3 else 0.0) * envelope(n, decay=0.1, sustain=0.62, release=0.04)
    return voice


def bass_voice(freq, seconds):
    return triangle(freq, seconds) * envelope(int(seconds * RATE), decay=0.1, sustain=0.75, release=0.02)


def tone_above_root(tones, index, octave):
    """A chord tone, keeping the chord in root position: tones that sort below the
    root go up an octave."""
    pitch = hz(tones[index] + str(octave))
    return pitch * 2 if pitch < hz(tones[0] + str(octave)) else pitch


def chord_arpeggio(chord_names, bar_steps, step, pattern, octave, volume):
    """Plucks the chord's notes in `pattern` on every step. -1 is a rest."""
    n = int(len(chord_names) * bar_steps * step * RATE)
    out = np.zeros(n + RATE)
    for bar, name in enumerate(chord_names):
        for i in range(bar_steps):
            index = pattern[i % len(pattern)]
            if index < 0:
                continue
            sound = pulse(tone_above_root(CHORDS[name], index, octave), step * 1.4, 0.125)
            mix_at(out, sound * decay_curve(sound.size, 11), (bar * bar_steps + i) * step)
    return out[:n] * volume


def bass_line(chord_names, bar_steps, step, pattern, octave):
    """pattern holds (step, chord tone index, length in steps) for each bar."""
    n = int(len(chord_names) * bar_steps * step * RATE)
    out = np.zeros(n + RATE)
    for bar, name in enumerate(chord_names):
        for at, index, length in pattern:
            pitch = tone_above_root(CHORDS[name], index, octave)
            mix_at(out, bass_voice(pitch, length * step), (bar * bar_steps + at) * step)
    return out[:n]


def drums(bars, bar_steps, step, kick, snare, hat, volume=1.0):
    n = int(bars * bar_steps * step * RATE)
    out = np.zeros(n + RATE)
    boom = triangle(glide(150, 45, 0.11), 0.11) * decay_curve(int(0.11 * RATE), 26)
    crack = noise(0.12, 21, 0.2) * decay_curve(int(0.12 * RATE), 32)
    tick = noise(0.03, 22) * decay_curve(int(0.03 * RATE), 170)
    for bar in range(bars):
        for at in kick:
            mix_at(out, 0.9 * boom, (bar * bar_steps + at) * step)
        for at in snare:
            mix_at(out, 0.32 * crack, (bar * bar_steps + at) * step)
        for at in hat:
            mix_at(out, 0.13 * tick, (bar * bar_steps + at) * step)
    return out[:n] * volume


def finish(name, layers, step, bars, bar_steps):
    """Mixes the layers, softening both ends so the loop doesn't click."""
    n = int(bars * bar_steps * step * RATE)
    mixed = np.zeros(n)
    for layer in layers:
        mixed[:min(n, layer.size)] += layer[:n]
    edge = int(0.004 * RATE)
    mixed[:edge] *= np.linspace(0, 1, edge)
    mixed[-edge:] *= np.linspace(1, 0, edge)
    write_wav(name, mixed * 0.5 / np.abs(mixed).max(), n)


def tunes():
    # Title: a slow, stately march at 96 beats a minute.
    step, bar = 60 / 96 / 2, 8
    chords = ["C", "G", "Am", "F", "C", "G", "F", "G", "Am", "Em", "F", "C", "Dm", "G", "C", "C"]
    melody = parse("""
        G4 . . C5 E5 . . D5 | D5 . . B4 G4 . . . | C5 . E5 . A5 . G5 E5 | F5 . . E5 C5 . . .
        G4 . C5 . E5 . G5 . | B5 . A5 G5 D5 . . . | A5 . G5 F5 C5 . D5 E5 | D5 . . . . . . .
        E5 . . A5 C6 . B5 A5 | G5 . . E5 B4 . . . | C5 . F5 . A5 . G5 F5 | E5 . G5 . C6 . . .
        D5 . F5 A5 D6 . C6 A5 | B5 . A5 G5 D5 . . . | E5 . G5 C6 . . B5 . | C6 . . . . . - .
    """)
    finish("title", [
        0.8 * sequence(melody, step, lead_voice(0.25)),
        chord_arpeggio(chords, bar, step, [0, 1, 2, 1], 3, 0.28),
        0.8 * bass_line(chords, bar, step, [(0, 0, 3), (4, 2, 3)], 2),
        drums(16, bar, step, [0, 4], [], [2, 6]),
    ], step, 16, bar)

    # Board: an easy walking tune at 120.
    step, bar = 60 / 120 / 2, 8
    chords = ["F", "Dm", "Bb", "C", "F", "Am", "Bb", "C", "Dm", "Am", "Bb", "F", "Gm", "C", "F", "C",
              "Bb", "F", "Bb", "C", "Dm", "Am", "Gm", "C"]
    melody = parse("""
        A4 . C5 . F5 . E5 . | D5 . F5 . A5 . . . | Bb5 . A5 . F5 . D5 . | E5 . G5 . C5 . . .
        A4 . C5 . F5 . A5 . | G5 . E5 . C5 . E5 . | F5 . D5 . Bb4 . D5 . | C5 . . . . . - .
        D5 . F5 . A5 . F5 . | E5 . C5 . A4 . C5 . | D5 . F5 . Bb5 . A5 G5 | F5 . . . A5 . . .
        G5 . Bb5 . G5 . D5 . | E5 . G5 . C6 . Bb5 . | A5 . F5 . C5 . F5 . | G5 . . . . . - .
        D5 . . F5 Bb5 . . A5 | F5 . . C5 A4 . . . | D5 . . F5 Bb5 . A5 . | G5 . E5 . C5 . . .
        A4 . D5 . F5 . A5 . | C5 . E5 . A5 . . . | Bb5 . G5 . D5 . G5 . | E5 . C5 . G4 . - .
    """)
    finish("board", [
        0.72 * sequence(melody, step, lead_voice(0.5)),
        chord_arpeggio(chords, bar, step, [-1, 1, 2, -1, 0, 2, 1, -1], 4, 0.2),
        0.85 * bass_line(chords, bar, step, [(0, 0, 2), (2, 2, 2), (4, 0, 2), (6, 1, 2)], 2),
        drums(24, bar, step, [0, 4], [], [0, 2, 4, 6], 0.75),
    ], step, 24, bar)

    # Battle: a driving minor key at 156.
    step, bar = 60 / 156 / 2, 8
    chords = ["Am", "Am", "F", "G", "Am", "Am", "Dm", "E", "F", "G", "Am", "Em", "F", "G", "E", "E"]
    melody = parse("""
        A4 . A4 C5 E5 . D5 C5 | B4 . A4 B4 C5 . E5 . | F5 . F5 E5 C5 . A4 . | G4 . B4 D5 G5 . . .
        A4 . C5 E5 A5 . G5 E5 | D5 . C5 B4 A4 . . . | D5 . F5 A5 D6 . A5 F5 | E5 . G#5 B5 E6 . . .
        F5 . A5 . C6 . A5 F5 | G5 . B5 . D6 . B5 G5 | A5 . C6 . E6 . C6 A5 | G5 . E5 . B4 . . .
        F5 . A5 C6 F5 . A5 C6 | G5 . B5 D6 G5 . B5 D6 | E5 . E5 G#5 B5 . E6 . | B5 . G#5 . E5 . . .
    """)
    finish("battle", [
        0.68 * sequence(melody, step, lead_voice(0.25, 0.0)),
        chord_arpeggio(chords, bar, step, [0, 2, 1, 2], 3, 0.2),
        0.95 * bass_line(chords, bar, step, [(i, 0, 1) for i in range(8)], 2),
        drums(16, bar, step, [0, 3, 4], [2, 6], list(range(8)), 0.9),
    ], step, 16, bar)

    # Shop: a small waltz, six steps to the bar.
    step, bar = 60 / 138 / 2, 6
    chords = ["C", "Am", "F", "G", "C", "Am", "Dm", "G", "F", "C", "Dm", "G", "C", "F", "G", "C"]
    melody = parse("""
        E5 . G5 . C6 . | A5 . . . E5 . | F5 . A5 . C6 . | B5 . . . G5 .
        E5 . G5 . C6 . | E6 . C6 . A5 . | F5 . A5 . D6 . | B5 . . . . .
        A5 . . . F5 . | G5 . E5 . C5 . | D5 . F5 . A5 . | G5 . . . B5 .
        C6 . . . G5 . | A5 . F5 . C5 . | D5 . G5 . B5 . | C6 . . . - .
    """)
    finish("shop", [
        0.62 * sequence(melody, step, lead_voice(0.25)),
        chord_arpeggio(chords, bar, step, [-1, -1, 0, 1, 2, 1], 4, 0.2),
        0.8 * bass_line(chords, bar, step, [(0, 0, 2)], 2),
        drums(16, bar, step, [0], [], [2, 4], 0.6),
    ], step, 16, bar)


if __name__ == "__main__":
    sfx()
    tunes()
