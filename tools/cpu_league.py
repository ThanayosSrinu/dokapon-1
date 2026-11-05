"""Plays many CPU games at once and adds them up by difficulty and by class.

Run from the project root:
    python tools/cpu_league.py <games> <weeks> [levels]

`levels` is one letter per player, E, N or H, and is turned one place per game so
that every seat gets every level. The default is ENNH. The logs go in _work/league.
"""
import collections
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

GODOT = "D:/Systems/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
AT_ONCE = 12


def play(game):
    seed, weeks, levels = game
    levels = levels[seed % 4:] + levels[:seed % 4]
    log = f"_work/league/{seed}_{levels}.log"
    with open(log, "w") as out:
        subprocess.run([GODOT, "--headless", "--path", ".", "res://tools/sim_game.tscn", "--",
                str(weeks), str(seed), levels], stdout=out, stderr=subprocess.STDOUT, timeout=900)
    with open(log) as text:
        lines = text.read().splitlines()
    errors = [line for line in lines if "SCRIPT ERROR" in line]
    finals = [line.split()[1:] for line in lines if line.startswith("FINAL")]
    return finals, errors


def table(title, rows):
    print(f"\n{title:<10} games  avg place  1st  avg worth  avg level  avg gold  avg towns")
    for name in sorted(rows):
        r = rows[name]
        n = len(r)
        print(f"{name:<10} {n:5}  {sum(x[0] for x in r) / n:9.2f}  {sum(x[0] == 1 for x in r):3}"
              f"  {sum(x[1] for x in r) / n:9.0f}  {sum(x[2] for x in r) / n:9.1f}"
              f"  {sum(x[3] for x in r) / n:8.0f}  {sum(x[4] for x in r) / n:9.1f}")


def main():
    games = int(sys.argv[1]) if len(sys.argv) > 1 else 12
    weeks = int(sys.argv[2]) if len(sys.argv) > 2 else 16
    levels = sys.argv[3] if len(sys.argv) > 3 else "ENNH"
    os.makedirs("_work/league", exist_ok=True)
    by_level = collections.defaultdict(list)
    by_class = collections.defaultdict(list)
    spreads = []
    errors = []
    with ThreadPoolExecutor(AT_ONCE) as pool:
        for finals, game_errors in pool.map(play, [(seed, weeks, levels) for seed in range(1, games + 1)]):
            errors += game_errors
            worths = []
            for level, class_id, place, worth, player_level, gold, towns in finals:
                row = (int(place), int(worth), int(player_level), int(gold), int(towns))
                by_level[level].append(row)
                by_class[class_id].append(row)
                worths.append(int(worth))
            if worths:
                spreads.append(max(worths) / max(min(worths), 1))
    table("Level", by_level)
    table("Class", by_class)
    if spreads:
        print(f"\nRichest over poorest: average {sum(spreads) / len(spreads):.1f}x, worst {max(spreads):.1f}x")
    print(f"Script errors: {len(errors)}")
    for line in sorted(set(errors))[:5]:
        print(line)


main()
