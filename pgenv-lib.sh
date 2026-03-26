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
    [ -z "$filter" ] && return 1  # no filter = don't skip

    # Direct match
    [ "$filter" = "$branch" ] && return 1

    # Match based on filter prefix (mirrors _pgenv_resolve_version)
    case "$filter" in
        36PGE*)
            [ "2QREL_${filter#36PGE}_STABLE_3_6" = "$branch" ] && return 1 ;;
        PGE*)
            [ "2QREL_${filter#PGE}_STABLE_dev" = "$branch" ] && return 1 ;;
        EDBAS*)
            [ "EDBAS_${filter#EDBAS}_STABLE" = "$branch" ] && return 1 ;;
        BDRPG*)
            [ "BDRPG_${filter#BDRPG}_STABLE" = "$branch" ] && return 1 ;;
        *)
            [ "REL${filter/./_}_STABLE" = "$branch" ] && return 1
            [ "REL_${filter}_STABLE" = "$branch" ] && return 1 ;;
    esac

    return 0  # skip
}

# Wait for parallel jobs, show progress bar, report failures.
# Args: logdir pid1 branch1 pid2 branch2 ...
_pgenv_wait_jobs() {
    local logdir=$1
    shift

    local -a pids=() branches=()
    while (( $# >= 2 )); do
        pids+=($1); branches+=($2)
        shift 2
    done

    local total=${#pids[@]} done=0 failed=0
    local -a failed_branches=()
    local cols=$(tput cols 2>/dev/null || echo 80)
    local bar_width=$(( cols - 30 ))
    (( bar_width < 10 )) && bar_width=10

    for (( i=0; i < total; i++ )); do
        if ! wait "${pids[$i]}"; then
            failed_branches+=("${branches[$i]}")
            (( failed++ ))
        fi
        (( done++ ))

        # Draw progress bar
        local pct=$(( done * 100 / total ))
        local filled=$(( done * bar_width / total ))
        local empty=$(( bar_width - filled ))
        printf "\r  [%s%s] %3d%%  %d/%d" \
            "$(printf '#%.0s' $(seq 1 $filled 2>/dev/null))" \
            "$(printf '.%.0s' $(seq 1 $empty 2>/dev/null))" \
            "$pct" "$done" "$total"
    done
    printf "\n"

    if (( failed > 0 )); then
        for b in "${failed_branches[@]}"; do
            printf "FAILED: %s  (see %s/%s.log)\n" "$b" "$logdir" "$b" >&2
        done
        printf "\n%d/%d branch(es) failed\n" "$failed" "$total" >&2
        return 1
    fi
    return 0
}

pgenv_pull_all() (
    cd "$SOURCE_DIR"
    local logdir="$SOURCE_DIR/.pgenv/logs/pull"
    mkdir -p "$logdir"
    local -a jobs=()

    # Phase 1: fetch once per repo (master dirs own the clones,
    # STABLE dirs are worktrees sharing the same .git objects)
    for a in $(ls -rd *master); do
        [ -d "$a" ] || continue
        (
            cd "$SOURCE_DIR/$a"
            git fetch --all -p
            git worktree prune
        ) > "$logdir/$a.log" 2>&1 &
        jobs+=($! "$a")
    done
    _pgenv_wait_jobs "$logdir" "${jobs[@]}"

    # Phase 2: checkout + reset in parallel (local per-worktree ops)
    jobs=()
    for a in $(ls -rd *master) $(ls -rd *STABLE*); do
        [ -d "$a" ] || continue
        (
            cd "$SOURCE_DIR/$a"
            git checkout "$a"
            git reset --hard "origin/$a"
        ) >> "$logdir/$a.log" 2>&1 &
        jobs+=($! "$a")
    done
    _pgenv_wait_jobs "$logdir" "${jobs[@]}"
)

pgenv_clean_all() (
    local filter="$1"
    cd "$SOURCE_DIR"
    local logdir="$SOURCE_DIR/.pgenv/logs/clean"
    mkdir -p "$logdir"
    local -a jobs=()

    for a in $(ls -rd *master) $(ls -rd *STABLE*); do
        [ -d "$a" ] || continue
        _pgenv_skip_branch "$filter" "$a" && continue

        (
            rm -fr "$SOURCE_DIR/.pgenv/versions/$a" "$SOURCE_DIR/.pgenv/data/$a"/*
            cd "$SOURCE_DIR/$a"
            git worktree prune
            make clean distclean 2>/dev/null; true
            git clean -fdx
        ) > "$logdir/$a.log" 2>&1 &
        jobs+=($! "$a")
    done

    _pgenv_wait_jobs "$logdir" "${jobs[@]}"
)

pgenv_configure_all() (
    set -e
    local filter="$1"
    local base_dir="${2:+$HOME/work/$2}"
    base_dir="${base_dir:-$SOURCE_DIR}"

    local -a ARGS=()
    if which port > /dev/null 2>&1; then
        ARGS+=(--with-libraries=/opt/local/lib --with-includes=/opt/local/include)
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
        ARGS+=(--with-includes="$INCLUDES")
        ARGS+=(--with-libraries="$LIBS")
    fi

    ARGS+=(--with-libxml --with-openssl)
    local -a DEBUG_ARGS=(--enable-depend --enable-cassert --enable-debug)

    if [ -n "$(perldoc -lm IPC::Run 2>/dev/null)" ]; then
        DEBUG_ARGS+=(--with-perl --enable-tap-tests)
    fi

    local CFLAGS="${CFLAGS:-}"
    CFLAGS+=" -Wall -Wextra -Wuninitialized -Wint-conversion -Wno-unused-parameter -Wno-sign-compare"
    CFLAGS+=" -ggdb -Og -g3 -fno-omit-frame-pointer -Wno-missing-field-initializers"

    if [ -f "/etc/SuSE-release" ] && [ "$(uname -m)" == 'x86_64' ]; then
        ARGS+=(--with-tclconfig=/usr/lib64)
    fi

    if (which ccache && which clang) > /dev/null 2>&1; then
        ARGS+=(CC="ccache clang -Qunused-arguments -fcolor-diagnostics")
    fi

    cd "$base_dir"

    for a in $(ls -rd *master) $(ls -rd *STABLE*); do
        [ -d "$a" ] || continue
        _pgenv_skip_branch "$filter" "$a" && continue

        local instdir="$base_dir/.pgenv/versions/$a"
        printf "\n\n\n\n"
        pushd "$a" > /dev/null
        printf "Running configure with the following arguments: --prefix=$instdir ${DEBUG_ARGS[*]} ${ARGS[*]} CFLAGS=$CFLAGS CPPFLAGS=$CPPFLAGS\n"
        ./configure --prefix="$instdir" "${DEBUG_ARGS[@]}" "${ARGS[@]}" CFLAGS="$CFLAGS" CPPFLAGS="$CPPFLAGS"
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
        local DEVBRANCH="dev/fi/$jira"
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
