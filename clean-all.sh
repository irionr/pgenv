#!/bin/bash

for a in dev master $(ls -rd REL*) $(ls -rd 2QREL*)
do
    # if the directory doesn't exist skip it
    [ -d $a ] || continue

    # if an argument is provided install only that version
    [ -n "$1" ] && [ "$1" != "$a" ] && [ "REL${1/./_}_STABLE" != "$a" ] && [ "REL_${1}_STABLE" != "$a" ] && [ "2QREL_${1#2Q}_STABLE_3_6" != "$a" ] && [ "2QREL_${1#2qm}_STABLE_dev" != "$a" ] && [ "EDBAS_${1#EDB}_STABLE" != "$a" ] && continue

    rm -fr "$HOME/.pgenv/versions/$a" "$HOME/.pgenv/data/$a/*"
    pushd $a
    make clean distclean
    popd
done
