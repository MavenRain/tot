#!/bin/zsh
# no set -u: the user's chpwd hook reads CARGO_TARGET_DIR unguarded
cd /Users/oobi/Documents/tot || exit 9
dunecho build; b=$?
[ "$b" -eq 0 ] && echo BUILD-OK || { echo BUILD-FAIL; exit "$b"; }
# dunecho test reports "0 run" on these custom runners (vacuous-pass trap):
# run the test executables directly and require BOTH to exit 0.
dune exec --root /Users/oobi/Documents/tot test/main.exe; t1=$?
dune exec --root /Users/oobi/Documents/tot test/surface.exe; t2=$?
{ [ "$t1" -eq 0 ] && [ "$t2" -eq 0 ]; } && echo TEST-OK || { echo TEST-FAIL; exit 1; }
exit 0
