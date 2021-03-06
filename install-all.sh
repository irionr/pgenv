#!/bin/bash

set -e
trap 'echo ERROR: installing $a FAILED!' ERR

if [ -n "$2" ]
then
    cd ~/work/$2/dev

    for a in dev master EDBAS-master $(ls -rd *REL*) $(ls -rd EDB*) pg
    do
        # if the directory doesn't exist skip it
        [ -d $a ] || continue

        # if an argument is provided install only that version
        [ -n "$1" ] && [ "$1" != "$a" ] && [ "REL${1/./_}_STABLE" != "$a" ] && [ "REL_${1}_STABLE" != "$a" ] && [ "2QREL_${1#2Q}_STABLE_3_6" != "$a" ] && [ "2QREL_${1#2qm}_STABLE_dev" != "$a" ] && [ "EDBAS_${1#EDB}_STABLE" != "$a" ] && continue

        instdir="$HOME/work/$2/.pgenv/versions/$a"
		[ -d $instdir ] && continue

        pushd $a
        make -j
        make install
        make -C contrib
        make -C contrib install
        popd
    done

else

    cd ~/pgsql

    for a in dev master EDBAS-master $(ls -rd *REL*) $(ls -rd EDB*)
    do
        # if the directory doesn't exist skip it
        [ -d $a ] || continue

        # if an argument is provided install only that version
        [ -n "$1" ] && [ "$1" != "$a" ] && [ "REL${1/./_}_STABLE" != "$a" ] && [ "REL_${1}_STABLE" != "$a" ] && [ "2QREL_${1#2Q}_STABLE_3_6" != "$a" ] && [ "2QREL_${1#2qm}_STABLE_dev" != "$a" ] && [ "EDBAS_${1#EDB}_STABLE" != "$a" ] && continue

        instdir="$HOME/.pgenv/versions/$a"

        rm -fr $a/DemoInstall "$instdir"
        pushd $a
        make -j$((`nproc`+1))
        make install
        make -C contrib -j$((`nproc`+1))
        make -C contrib install
        popd
    done
fi
