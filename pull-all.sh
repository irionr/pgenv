#!/bin/bash -e
die() {
    echo $1
    exit
}

for a in pglogical bdr master; do
    pushd $a
    git fetch --all -p
    git checkout master
    git reset --hard origin/master
    git worktree prune
    popd
done

for a in $(ls -rd *STABLE*) EDBAS-master BDRPG-master; do
    pushd $a
    git fetch --all -p
    git checkout $a
    git reset --hard origin/$a
    git worktree prune
    popd
done
