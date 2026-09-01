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
# M2 script gates: the prelude and both examples must check AND run.
# Success stays quiet (markers only); a failure replays the captured
# output, where the CLI prints its error, then exits 1.
out=$(dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- check /Users/oobi/Documents/tot/stdlib/prelude.tot 2>&1)
[ $? -eq 0 ] && echo PASS-CHECK-PRELUDE || { printf '%s\n' "$out"; echo FAIL-CHECK-PRELUDE; exit 1; }
out=$(dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /Users/oobi/Documents/tot/stdlib/prelude.tot 2>&1)
[ $? -eq 0 ] && echo PASS-RUN-PRELUDE || { printf '%s\n' "$out"; echo FAIL-RUN-PRELUDE; exit 1; }
out=$(dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- check /Users/oobi/Documents/tot/examples/church.tot 2>&1)
[ $? -eq 0 ] && echo PASS-CHECK-CHURCH || { printf '%s\n' "$out"; echo FAIL-CHECK-CHURCH; exit 1; }
out=$(dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /Users/oobi/Documents/tot/examples/church.tot 2>&1)
[ $? -eq 0 ] && echo PASS-RUN-CHURCH || { printf '%s\n' "$out"; echo FAIL-RUN-CHURCH; exit 1; }
out=$(dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- check /Users/oobi/Documents/tot/examples/nat.tot 2>&1)
[ $? -eq 0 ] && echo PASS-CHECK-NAT || { printf '%s\n' "$out"; echo FAIL-CHECK-NAT; exit 1; }
out=$(dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /Users/oobi/Documents/tot/examples/nat.tot 2>&1)
[ $? -eq 0 ] && echo PASS-RUN-NAT || { printf '%s\n' "$out"; echo FAIL-RUN-NAT; exit 1; }
echo SCRIPTS-OK
exit 0
