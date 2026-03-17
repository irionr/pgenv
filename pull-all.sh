#!/bin/bash -e
die() {
    echo $1
    exit
}

SOURCE_DIR="$HOME/pgsql"

pushd $SOURCE_DIR

for a in $(ls -rd *master) $(ls -rd *STABLE*); do
    pushd $a
    git fetch --all -p
    git checkout $a
    git reset --hard origin/$a
    git worktree prune
    popd
done

popd
