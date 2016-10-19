#!/bin/sh

chirp() { [ $verbose ] && shout "$*"; return 0; }

shout() { echo "$0: $*" >&2;}

barf() { shout "$*"; exit 111; }

safe() { "$@" || barf "cannot $*"; }

which stack || barf "stack is not installed, but this should be easy to do with cabal just make sure you symlink the executable"
safe rm -rf .stack-work
safe stack build --library-profiling --executable-profiling
which hp2ps || barf "hp2ps not installed"
[ -L ./spaceleak ] || safe ln -s $(stack exec -- which spaceleak) .
[ -d ./prof-results ] || safe mkdir prof-results
exit 0
