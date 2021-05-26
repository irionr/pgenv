#!/bin/bash


case "$1" in
  "")
    echo "ERROR: missing argument" >&2
    exit 1
    ;;
  2qm1*)
    BRANCH=2QREL_${1#2qm}_STABLE_dev
    VER=2Q13
    MASTER=2QPG-master
    ;;
  2q1*|2Q1*)
    BRANCH=2QREL_${1#2[q|Q]}_STABLE_3_6
    VER=${1#2[q|Q]}
    MASTER=2QPG-master
    ;;
  master|14)
    BRANCH=master
    VER=14
    MASTER=PG-master
    ;;
  1*)
    BRANCH="REL_${1}_STABLE"
    VER="$1"
    MASTER=PG-master
    ;;
  EDBAS-master|14)
    BRANCH=EDBAS-master
    VER=14
    MASTER=EDBAS-master
    ;;
  EDB1*)
    BRANCH=EDBAS_${1#EDB}_STABLE
    VER=${1#EDB}
    MASTER=EDBAS-master
    ;;
  *)
    BRANCH="REL${1/./_}_STABLE"
    VER="$1"
    MASTER=PG-master
    ;;
esac

git --git-dir=$HOME/pgsql/$MASTER/.git/ config gc.auto 0

if [ ! -d "$HOME/pgsql/$MASTER" ]; then
    echo "ERROR: missing $MASTER directory" >&2
    exit 1
fi

if [ -d "$BRANCH" ]; then
    echo "Nothing to do"
    exit 0
fi

if [ ! -e $HOME/pgsql/git-new-workdir ]; then
   curl -L https://raw.github.com/git/git/master/contrib/workdir/git-new-workdir > $HOME/pgsql/git-new-workdir
fi

$SHELL $HOME/pgsql/git-new-workdir $ORIGIN_PG_REPO.git/ $BRANCH $BRANCH
