#!/bin/bash
# usage: ablate.sh "1,3,5,7" slot=rank ...   one talent at a time, maxed (tree rules ignored)
H=$1; shift
for B in "$@"; do
  python balance.py --heroes $H --builds "r:$B" --seeds 4 --levels $(seq -s, 1 23) --skill 2 | tail -n +2 | sed "s/^/[$B] /"
done
