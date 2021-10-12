#!/bin/bash

for a in pglogical bdr master $(ls -rd *REL*)
do
    # if the directory doesn't exist skip it
    [ -d $a ] || continue

    # if an argument is provided install only that version
    [ -n "$1" ] &&
        [ "$1" != "$a" ] &&
        [ "REL${1/./_}_STABLE" != "$a" ] &&
        [ "REL_${1}_STABLE" != "$a" ] &&
        [ "2QREL_${1#362q}_STABLE_3_6" != "$a" ] &&
        [ "2QREL_${1#372q}_STABLE_dev" != "$a" ] &&
        [ "2QREL_${1#m2q}_STABLE_dev" != "$a" ] &&
        [ "EDBAS_${1#EDB}_STABLE" != "$a" ] &&
        [ "BDRPG_${1#BDRPG}_STABLE" != "$a" ] &&
        continue

    rm -fr "$HOME/.pgenv/versions/$a" "$HOME/.pgenv/data/$a/*"
    pushd $a
    git worktree prune
    # make clean distclean
    popd
done
