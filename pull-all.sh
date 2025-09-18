#!/bin/bash -e
die() {
    echo $1
    exit
}

for a in $(ls -rd *master) $(ls -rd *STABLE*); do
    pushd $a
    git fetch --all -p
    git checkout $a
    git reset --hard origin/$a
    git worktree prune
    popd
done
