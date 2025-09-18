#!/bin/bash

for a in $(ls -rd *master) $(ls -rd *STABLE*); do
    # if the directory doesn't exist skip it
    [ -d $a ] || continue

    # if an argument is provided install only that version
    [ -n "$1" ] &&
        [ "$1" != "$a" ] &&
        [ "REL${1/./_}_STABLE" != "$a" ] &&
        [ "REL_${1}_STABLE" != "$a" ] &&
        [ "2QREL_${1#36PGE}_STABLE_3_6" != "$a" ] &&
        [ "2QREL_${1#PGE}_STABLE_dev" != "$a" ] &&
        [ "EDBAS_${1#EDBAS}_STABLE" != "$a" ] &&
        [ "BDRPG_${1#BDRPG}_STABLE" != "$a" ] &&
        continue

    rm -fr "$HOME/.pgenv/versions/$a" "$HOME/.pgenv/data/$a/*"
    pushd $a
    git worktree prune
    make clean distclean
    git clean -fdx
    popd
done
