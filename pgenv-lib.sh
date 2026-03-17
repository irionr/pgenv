#!/bin/bash
#
# pgenv-lib.sh - shared library for pgenv scripts
#
# Provides functions for managing PostgreSQL/BDR source trees.
# Sourced by pgenv.sh (interactive) and by the thin wrapper scripts.

: "${SOURCE_DIR:=$HOME/pgsql}"
CURRENT_DEVEL=19

# Resolves a version string (e.g. "17", "PGE14", "BDRPG16") into branch
# metadata. Sets: _PGENV_VERSION, _PGENV_BRANCH, _PGENV_MASTER, _PGENV_BASE_PORT
_pgenv_resolve_version() {
    local input="$1"
    _PGENV_BASE_PORT=5400

    case "$input" in
    master | ${CURRENT_DEVEL})
        _PGENV_VERSION=$CURRENT_DEVEL
        _PGENV_BRANCH=master
        _PGENV_MASTER=master
        ;;
    1*)
        _PGENV_VERSION="$input"
        _PGENV_BRANCH="REL_${input}_STABLE"
        _PGENV_MASTER=master
        ;;
    PGE)
        _PGENV_VERSION=$CURRENT_DEVEL
        _PGENV_BRANCH="BDRPG-master"
        _PGENV_MASTER=2QREL-master
        _PGENV_BASE_PORT=6400
        ;;
    PGE1*)
        _PGENV_VERSION="${input#PGE}"
        _PGENV_BRANCH="2QREL_${_PGENV_VERSION}_STABLE_dev"
        _PGENV_MASTER=2QREL-master
        _PGENV_BASE_PORT=7400
        ;;
    36PGE1*)
        _PGENV_VERSION="${input#36PGE}"
        _PGENV_BRANCH="2QREL_${_PGENV_VERSION}_STABLE_3_6"
        _PGENV_MASTER=2QREL-master
        _PGENV_BASE_PORT=8400
        ;;
    EDBAS)
        _PGENV_VERSION=$CURRENT_DEVEL
        _PGENV_BRANCH="EDBAS-master"
        _PGENV_MASTER=EDBAS-master
        _PGENV_BASE_PORT=9400
        ;;
    EDBAS1*)
        _PGENV_VERSION="${input#EDBAS}"
        _PGENV_BRANCH="EDBAS_${_PGENV_VERSION}_STABLE"
        _PGENV_MASTER=EDBAS-master
        _PGENV_BASE_PORT=10400
        ;;
    BDRPG)
        _PGENV_VERSION=$CURRENT_DEVEL
        _PGENV_BRANCH="BDRPG-master"
        _PGENV_MASTER=BDRPG-master
        _PGENV_BASE_PORT=11400
        ;;
    BDRPG1*)
        _PGENV_VERSION="${input#BDRPG}"
        _PGENV_BRANCH="BDRPG_${_PGENV_VERSION}_STABLE"
        _PGENV_MASTER=BDRPG-master
        _PGENV_BASE_PORT=12400
        ;;
    *)
        _PGENV_VERSION="$input"
        _PGENV_BRANCH="REL${input/./_}_STABLE"
        _PGENV_MASTER=master
        ;;
    esac
}

# Returns 0 (true = skip) when $branch does NOT match $filter.
_pgenv_skip_branch() {
    local filter="$1" branch="$2"
    [ -n "$filter" ] &&
        [ "$filter" != "$branch" ] &&
        [ "REL${filter/./_}_STABLE" != "$branch" ] &&
        [ "REL_${filter}_STABLE" != "$branch" ] &&
        [ "2QREL_${filter#36PGE}_STABLE_3_6" != "$branch" ] &&
        [ "2QREL_${filter#PGE}_STABLE_dev" != "$branch" ] &&
        [ "EDBAS_${filter#EDBAS}_STABLE" != "$branch" ] &&
        [ "BDRPG_${filter#BDRPG}_STABLE" != "$branch" ]
}

pgenv_pull_all() (
    set -e
    cd "$SOURCE_DIR"

    for a in $(ls -rd *master) $(ls -rd *STABLE*); do
        pushd "$a" > /dev/null
        git fetch --all -p
        git checkout "$a"
        git reset --hard "origin/$a"
        git worktree prune
        popd > /dev/null
    done
)

pgenv_clean_all() (
    local filter="$1"
    cd "$SOURCE_DIR"

    for a in $(ls -rd *master) $(ls -rd *STABLE*); do
        [ -d "$a" ] || continue
        _pgenv_skip_branch "$filter" "$a" && continue

        rm -fr "$SOURCE_DIR/.pgenv/versions/$a" "$SOURCE_DIR/.pgenv/data/$a"/*
        pushd "$a" > /dev/null
        git worktree prune
        make clean distclean
        git clean -fdx
        popd > /dev/null
    done
)

pgenv_configure_all() (
    set -e
    local filter="$1"
    local base_dir="${2:+$HOME/work/$2}"
    base_dir="${base_dir:-$SOURCE_DIR}"

    local ARGS=
    if which port > /dev/null 2>&1; then
        ARGS+=" --with-libraries=/opt/local/lib --with-includes=/opt/local/include"
    elif which brew > /dev/null 2>&1; then
        local INCLUDES= LIBS=
        for pkg in openssl readline libxml2; do
            local prefix=$(brew --prefix "$pkg")
            if [ -n "$INCLUDES" ]; then INCLUDES+=:; fi
            INCLUDES+="$prefix/include"
            if [ -n "$LIBS" ]; then LIBS+=:; fi
            LIBS+="$prefix/lib"
            export PATH="$prefix/bin:$PATH"
        done
        ARGS+=" --with-includes=$INCLUDES"
        ARGS+=" --with-libraries=$LIBS"
    fi

    ARGS+=" --with-libxml --with-openssl"
    local DEBUG_ARGS="--enable-depend --enable-cassert --enable-debug "

    if [ -n "$(perldoc -lm IPC::Run 2>/dev/null)" ]; then
        DEBUG_ARGS+=" --with-perl --enable-tap-tests"
    fi

    local CFLAGS="${CFLAGS:-}"
    CFLAGS+=" -Wall -Wextra -Wuninitialized -Wint-conversion -Wno-unused-parameter -Wno-sign-compare"
    CFLAGS+=" -ggdb -Og -g3 -fno-omit-frame-pointer -Wno-missing-field-initializers "

    if [ -f "/etc/SuSE-release" ] && [ "$(uname -m)" == 'x86_64' ]; then
        ARGS+=" --with-tclconfig=/usr/lib64"
    fi

    if (which ccache && which clang) > /dev/null 2>&1; then
        ARGS+=" CC='ccache clang -Qunused-arguments -fcolor-diagnostics'"
    fi

    cd "$base_dir"

    for a in $(ls -rd *master) $(ls -rd *STABLE*); do
        [ -d "$a" ] || continue
        _pgenv_skip_branch "$filter" "$a" && continue

        local instdir="$base_dir/.pgenv/versions/$a"
        printf "\n\n\n\n"
        pushd "$a" > /dev/null
        printf "Running configure with the following arguments: --prefix=$instdir ${DEBUG_ARGS} ${ARGS} CFLAGS=$CFLAGS CPPFLAGS=$CPPFLAGS\n"
        ./configure --prefix="$instdir" ${DEBUG_ARGS} ${ARGS} CFLAGS="$CFLAGS" CPPFLAGS="$CPPFLAGS"
        popd > /dev/null
        printf "\n\n\n\n"
    done
)

pgenv_install_all() (
    set -e
    trap 'echo ERROR: installing $a FAILED!' ERR
    local filter="$1"
    local base_dir="${2:+$HOME/work/$2}"
    base_dir="${base_dir:-$SOURCE_DIR}"

    cd "$base_dir"

    for a in $(ls -rd *master) $(ls -rd *STABLE*); do
        [ -d "$a" ] || continue
        _pgenv_skip_branch "$filter" "$a" && continue

        local instdir="$base_dir/.pgenv/versions/$a"

        rm -fr "$a/DemoInstall" "$instdir"
        printf "\n\n\n\n"
        pushd "$a" > /dev/null
        printf "Building $a\n"
        make -j$(nproc) && make install && make -C contrib && make -C contrib install
        popd > /dev/null
        printf "\n\n\n\n"
    done
)

pgenv_new_branch() (
    set -e
    local version="$1" jira="$2"

    if [ -z "$version" ]; then
        echo "ERROR: missing argument" >&2
        return 1
    fi

    _pgenv_resolve_version "$version"
    local BRANCH=$_PGENV_BRANCH
    local MASTER=$_PGENV_MASTER

    git --git-dir="$SOURCE_DIR/$MASTER/.git/" config gc.auto 0

    if [ ! -d "$SOURCE_DIR/$MASTER" ]; then
        echo "ERROR: missing $MASTER directory" >&2
        return 1
    fi

    if [ -n "$jira" ]; then
        local TARGET_DIR="$HOME/work/$jira"
        local DEVBRANCH="dev/$jira"
        pushd "$SOURCE_DIR/$MASTER" > /dev/null
        git worktree add "$TARGET_DIR/$BRANCH" "$DEVBRANCH" ||
            git worktree add -b "$DEVBRANCH" "$TARGET_DIR/$BRANCH" "$BRANCH"
        popd > /dev/null
    else
        if [ -d "$SOURCE_DIR/$BRANCH" ]; then
            echo "Nothing to do"
            return 0
        fi
        pushd "$SOURCE_DIR/$MASTER" > /dev/null
        git worktree add "$SOURCE_DIR/$BRANCH" "$BRANCH"
        popd > /dev/null
    fi
)
