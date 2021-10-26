#!/bin/bash

SOURCE_DIR="$HOME/pgsql"
TARGET_DIR="$HOME/pgsql"

case "$1" in
  "")
    echo "ERROR: missing argument" >&2
    exit 1
    ;;
  # community
  master)
    BRANCH=master
    VER=15
    MASTER=master
    ;;
  1*)
    BRANCH="REL_${1/./_}_STABLE"
    VER="$1"
    MASTER=master
    ;;
  # PGE (2QPG)
  m2q1*) # PGE compatible with bdr master (4.0)
    BRANCH=2QREL_${1#m2q}_STABLE_dev
    VER={1#m2q}
    MASTER=2QPG-master
    ;;
  372q1*) # PGE compatible with bdr 3.7
    BRANCH=2QREL_${1#372q}_STABLE_dev
    VER=${1#372q}
    MASTER=2QPG-master
    ;;
  362q1*) # PGE compatible with bdr 3.6
    BRANCH=2QREL_${1#362q}_STABLE_3_6
    VER=${1#362q}
    MASTER=2QREL_${1#362q}_STABLE_3_6
    ;;
  # EDB Advance Server
  EDBAS-master)
    BRANCH=EDBAS-master
    VER=14
    MASTER=EDBAS-master
    ;;
  EDB1*)
    BRANCH=EDBAS_${1#EDB}_STABLE
    VER=${1#EDB}
    MASTER=EDBAS-master
    ;;
  BDRPG1*)
    BRANCH=BDRPG_${1#BDRPG}_STABLE
    VER=${1#BDRPG}
    MASTER=BDRPG-master
    ;;
  *)
    BRANCH="REL${1/./_}_STABLE"
    VER="$1"
    MASTER=master
    ;;
esac

git --git-dir=$HOME/pgsql/$MASTER/.git/ config gc.auto 0

if [ ! -d "$SOURCE_DIR/$MASTER" ]; then
    echo "ERROR: missing $MASTER directory" >&2
    exit 1
fi

if [ -n "$2" ];
then
    TARGET_DIR="$HOME/work/$2"
	DEVBRANCH="dev/$2"
	pushd $SOURCE_DIR/$MASTER
	git worktree add $TARGET_DIR/$BRANCH $DEVBRANCH ||
    	git worktree add -b $DEVBRANCH $TARGET_DIR/$BRANCH
	popd
else
	if [ -d "$TARGET_DIR/$BRANCH" ]; then
	    echo "Nothing to do"
	    exit 0
	fi
	pushd $SOURCE_DIR/$MASTER
	git worktree add $TARGET_DIR/$BRANCH $BRANCH ||
	    git worktree add -b dev/$2 $TARGET_DIR/$BRANCH
	popd
fi
