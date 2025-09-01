#!/bin/bash
set -e

# Set the current PostgreSQL development branch
CURRENT_DEVEL=19

SOURCE_DIR="$HOME/pgsql"
TARGET_DIR="$HOME/pgsql"

case "$1" in
"")
  echo "ERROR: missing argument" >&2
  exit 1
  ;;
master | ${CURRENT_DEVEL})
  BRANCH=master
  VER=$CURRENT_DEVEL
  MASTER=master
  ;;
1*)
  BRANCH="REL_${1/./_}_STABLE"
  VER="$1"
  MASTER=master
  ;;
PGE1*)
  BRANCH=2QREL_${1#PGE}_STABLE_dev
  VER=${1#PGE}
  MASTER=2QPG-master
  ;;
36PGE1*)
  BRANCH=2QREL_${1#36PGE}_STABLE_3_6
  VER=${1#36PGE}
  MASTER=2QPG-master
  ;;
EDBAS)
  BRANCH=EDBAS-master
  VER=$CURRENT_DEVEL
  MASTER=EDBAS-master
  ;;
EDBAS1*)
  BRANCH=EDBAS_${1#EDBAS}_STABLE
  VER=${1#EDBAS}
  MASTER=EDBAS-master
  ;;
BDRPG)
  BRANCH=BDRPG-master
  VER=$CURRENT_DEVEL
  MASTER=BDRPG-master
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

if [ -n "$2" ]; then
  TARGET_DIR="$HOME/work/$2"
  DEVBRANCH="dev/$2"
  pushd $SOURCE_DIR/$MASTER
  git worktree add $TARGET_DIR/$BRANCH $DEVBRANCH ||
    git worktree add -b $DEVBRANCH $TARGET_DIR/$BRANCH $BRANCH
  popd
else
  if [ -d "$TARGET_DIR/$BRANCH" ]; then
    echo "Nothing to do"
    exit 0
  fi
  pushd $SOURCE_DIR/$MASTER
  git worktree add $TARGET_DIR/$BRANCH $BRANCH
  popd
fi
