#!/usr/bin/env bash
# Reset and run every pitch_* case end to end (same as the `ddd` alias:
# dust_pre && dust && dust_post).
#
# Usage: ./run_all.sh [start end]    e.g. ./run_all.sh -3 8  -> pitch_-3 .. pitch_8
#        with no arguments it asks for the start and end angle

set -uo pipefail

BIN="${DUST_BIN:-$HOME/cfd/dust/build/bin}"
root="$(cd "$(dirname "$0")" && pwd)"
cd "$root"

if [ $# -ge 2 ]; then start=$1; end=$2; else
  read -rp "Starting angle: " start
  read -rp "Ending angle:   " end
fi

if ! [[ $start =~ ^-?[0-9]+$ && $end =~ ^-?[0-9]+$ ]] || [ "$start" -gt "$end" ]; then
  echo "Start and end must be integers (negative allowed) with start <= end." >&2; exit 1
fi

cases=()
for ((a = start; a <= end; a++)); do
  if [ -d "pitch_$a" ]; then cases+=("pitch_$a"); else echo "Skipping pitch_$a (no such directory)"; fi
done
[ ${#cases[@]} -gt 0 ] || { echo "No cases to run." >&2; exit 1; }

failed=()
for c in "${cases[@]}"; do
  echo "################ $c ################"
  if ( cd "$root/$c" && ./reset.sh && "$BIN/dust_pre" && "$BIN/dust" && "$BIN/dust_post" ); then
    echo ">>> $c done"
  else
    echo ">>> $c FAILED"
    failed+=("$c")
  fi
done

echo
if [ ${#failed[@]} -gt 0 ]; then echo "Failed: ${failed[*]}"; exit 1; fi
echo "All ${#cases[@]} cases finished."
