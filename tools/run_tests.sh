#!/usr/bin/env bash
# Runs every test scene with no window and prints one line each, then the FAIL lines.
#
#   bash tools/run_tests.sh            every test
#   bash tools/run_tests.sh town bank  only those
set -u
cd "$(dirname "$0")/.." || exit 1
GODOT="D:/Systems/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
mkdir -p _work/tests

names=("$@")
if [ ${#names[@]} -eq 0 ]; then
    for file in tools/test_*.tscn; do
        name="${file#tools/test_}"
        names+=("${name%.tscn}")
    done
fi

bad=0
for name in "${names[@]}"; do
    log="_work/tests/$name.log"
    timeout 280 "$GODOT" --headless --path . "res://tools/test_$name.tscn" > "$log" 2>&1
    code=$?
    if [ $code -eq 0 ] && grep -q "TESTS OK" "$log"; then
        echo "ok    $name"
    else
        bad=1
        echo "FAIL  $name (exit $code)"
        grep -E "FAIL:|SCRIPT ERROR|Parse Error|Failed to|TEST\(S\) FAILED" "$log" | head -25
    fi
done
exit $bad
