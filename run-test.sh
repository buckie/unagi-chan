#!/bin/sh

chirp() { [ $verbose ] && shout "$*"; return 0; }

shout() { echo "$0: $*" >&2;}

barf() { shout "$*"; exit 111; }

safe() { "$@" || barf "cannot $*"; }

[ $1 ] || barf 'Please provide a profiling flag, e.g. `./run-test.sh -hr -i0.01`; NB: -L500 is already included'

[ -f spaceleak.aux ] && rm spaceleak.aux
[ -f spaceleak.hp ] && safe rm spaceleak.hp
[ -f spaceleak.prof ] && safe rm spaceleak.prof
[ -f spaceleak.ps ] && safe rm spaceleak.ps
shout "Running ./spaceleak +RTS -L500 $*"
safe stack build
safe ./spaceleak +RTS $*
safe hp2ps -M -c spaceleak.hp
safe mv spaceleak.ps "prof-results/spaceleak.$(echo $* | sed 's/ //g').ps"
shout "Results will be saved to: prof-results/spaceleak.$(echo $* | sed 's/ //g').ps"

exit 0
