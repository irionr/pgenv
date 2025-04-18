#!/bin/bash

set -e
trap 'echo ERROR: installing $a FAILED!' ERR

if [ -n "$2" ]; then
    BASE_DIR="$HOME/work/$2/"
else
    BASE_DIR="$HOME/pgsql"
fi

pushd $BASE_DIR

for a in $(ls -rd *STABLE*); do
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

    instdir="$BASE_DIR/.pgenv/versions/$a"

    rm -fr $a/DemoInstall "$instdir"
	printf "\n\n\n\n"
    pushd $a
	printf "Installing $a\n"
    bear -- make -j && make -j install && bear -- make -C contrib && make -C contrib install
    # return in the $BASE_DIR and remain there
    popd
	printf "\n\n\n\n"
done
