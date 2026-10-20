#!/bin/bash
# usage: ladder.sh HERO "set1" "set2" ...   (runs the no-talent baseline for each override set)
H=$1; shift
for S in "$@"; do
  echo "== hero $H  $S"
  python balance.py --heroes $H --builds none --seeds 16 --levels $(seq -s, 1 23) --skill 2 --set "$S" | tail -1
done
