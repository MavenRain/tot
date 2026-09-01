#!/bin/zsh
# no set -u: the user's chpwd hook reads CARGO_TARGET_DIR unguarded
cd /Users/oobi/Documents/tot || exit 9
dunecho build; b=$?
[ "$b" -eq 0 ] && echo BUILD-OK || { echo BUILD-FAIL; exit "$b"; }
dunecho test; t=$?
[ "$t" -eq 0 ] && echo TEST-OK || { echo TEST-FAIL; exit "$t"; }
exit 0
