#!/bin/zsh
_pgenv_hook() {
    if [[ -n "$PG_VERSION" ]]; then
        case "$PG_BRANCH" in
        2QREL*)
            echo -n "PGE$PG_VERSION"
            ;;
        EDBAS*)
            echo -n "EDBAS$PG_VERSION"
            ;;
        BDRPG*)
            echo -n "BDRPG$PG_VERSION"
            ;;
        *)
            echo -n "PG$PG_VERSION"
            ;;
        esac
    fi

    if [[ -n "$PG_WORKON" ]]; then
        echo -n "/$PG_WORKON"
    fi

    if [[ -n "$EXTENSION_BRANCH" ]]; then
        echo -n "/$EXTENSION_BRANCH"
    fi
}

if ! [[ "$PROMPT_COMMAND" =~ _pgenv_hook ]]; then
    PROMPT_COMMAND="_pgenv_hook;$PROMPT_COMMAND"
fi

pgworkon() {
    local SOURCE_DIR="$HOME/pgsql"
    local CURRENT_DEVEL=18
    local BASE_PORT=5400
    local JIRA=0
    # clenup old env
    if [ -n "$PG_OLD_PATH" ]; then
        export PATH=$PG_OLD_PATH
        unset PG_OLD_PATH
    fi
    unset PGSRC PGDATA PGHOST PGDATABASE PGUSER PGPORT PG_BRANCH PG_VERSION PG_WORKON EXTENSION_BRANCH PG_TEST_PORT_DIR

    usage() {
        [ -n "$1" ] && echo "$1" 1>&2
        echo 1>&2
        echo "$0: pgworkon <flavor><version> [<JIRA> [<BDR base branch>]] " 1>&2
    }

    case "$1" in
    "")
        usage "ERROR: missing argument"
        return 1
        ;;
    master | $CURRENT_DEVEL)
        PG_VERSION=$CURRENT_DEVEL
        PG_BRANCH=master
        ;;
    1*)
        PG_VERSION="$1"
        PG_BRANCH="REL_${1}_STABLE"
        ;;
    PGE)
        PG_VERSION=$CURRENT_DEVEL
        PG_BRANCH="BDRPG-master"
        BASE_PORT=6400
        ;;
    PGE1*)
        PG_VERSION="${1#PGE}"
        PG_BRANCH="2QREL_${PG_VERSION}_STABLE_dev"
        BASE_PORT=7400
        ;;
    36PGE1*)
        PG_VERSION="${1#36PGE}"
        PG_BRANCH="2QREL_${PG_VERSION}_STABLE_3_6"
        BASE_PORT=8400
        ;;
    EDBAS)
        PG_VERSION=$CURRENT_DEVEL
        PG_BRANCH="EDBAS-master"
        BASE_PORT=9400
        ;;
    EDBAS1*)
        PG_VERSION="${1#EDBAS}"
        PG_BRANCH="EDBAS_${PG_VERSION}_STABLE"
        BASE_PORT=10400
        ;;
    BDRPG)
        PG_VERSION=$CURRENT_DEVEL
        PG_BRANCH="BDRPG-master"
        BASE_PORT=11400
        ;;
    BDRPG1*)
        PG_VERSION="${1#BDRPG}"
        PG_BRANCH="BDRPG_${PG_VERSION}_STABLE"
        BASE_PORT=12400
        ;;
    *)
        PG_VERSION="$1"
        PG_BRANCH="REL${1/./_}_STABLE"
        ;;
    esac

    case "$3" in
    master | 6)
        EXTENSION_BRANCH="master"
        ;;
    5)
        EXTENSION_BRANCH="REL_5_STABLE"
        ;;
    4)
        EXTENSION_BRANCH="REL_4_STABLE"
        ;;
    3.7)
        EXTENSION_BRANCH="REL3_7_STABLE"
        ;;
    3.6)
        EXTENSION_BRANCH="REL3_6_STABLE"
        ;;
    esac

    PG_VERS_NUM=${PG_VERSION/./}
    if [ ${PG_VERSION%%.*} -ge 10 ]; then
        PG_VERS_NUM=${PG_VERS_NUM}0
    fi

    if [ -n "$2" ]; then
        export PG_WORKON=$2
        JIRA="${2#BDR-}"
        local BASE_DIR="$HOME/work/$2"
        local PG_DIR="$BASE_DIR/.pgenv"
        PG_TEST_PORT_DIR="tmp_check"

        if [ ! -d "$BASE_DIR" ]; then
            # create a new dev branch or checkout if exists
            pushd $PGL_REPO
            git worktree add -b dev/$2 $BASE_DIR/pgl $EXTENSION_BRANCH ||
                git worktree add $BASE_DIR/pgl dev/$2
            popd
            pushd $BDR_REPO
            git worktree add -b dev/$2 $BASE_DIR/bdr $EXTENSION_BRANCH ||
                git worktree add $BASE_DIR/bdr dev/$2
            popd
            $SOURCE_DIR/new-branch.sh $1 $2
            $SOURCE_DIR/configure-all.sh $1 $2
            $SOURCE_DIR/install-all.sh $1 $2
        fi
        cd $BASE_DIR/bdr
        echo -ne "\e]1;${1} - ${2}\a"
    else
        local BASE_DIR="$SOURCE_DIR"
        local PG_DIR="$SOURCE_DIR/.pgenv"
        PG_TEST_PORT_DIR="tmp_check"
        if [ ! -d "$BASE_DIR/$PG_BRANCH" ]; then
            $SOURCE_DIR/new-branch.sh $1
            $SOURCE_DIR/configure-all.sh $1
            $SOURCE_DIR/install-all.sh $1
        fi
    fi

    local DIR="$SOURCE_DIR/$PG_BRANCH"
    local BINDIR="$PG_DIR/versions/$PG_BRANCH/bin"
    local DATADIR="$PG_DIR/data/$PG_BRANCH/main"
    if [ ! -d "$DIR" ]; then
        usage "Unknown version $1"
        return 1
    fi
    if [ -z "$PG_OLD_PATH" ]; then
        PG_OLD_PATH=$PATH
    fi
    PGSRC=$DIR
    export PATH="$BINDIR:$PG_OLD_PATH"
    export PGDATA="$DATADIR"
    export PGDATABASE="postgres"
    export PGUSER="postgres"
    export PGPORT=$((BASE_PORT + PG_VERS_NUM + JIRA))
    export PGHOST=/tmp

    if which dpkg-architecture >/dev/null; then
        """
        No undo action on pgdeactivate. Having libreadline preloaded
        shouldn't be of any harm
        """
        if ! [[ "$LD_PRELOAD" =~ 'libreadline.so' ]]; then
            export LD_PRELOAD=/lib/$(dpkg-architecture -qDEB_BUILD_GNU_TYPE)/libreadline.so.6:$LD_PRELOAD
        fi
    fi

    pgreinit() {
        pgstop
        rm -f /tmp/pgsql-$PG_BRANCH-$PG_WORKON.log
        rm -fr "$PGDATA"
        mkdir -p "$PGDATA"
        initdb -U postgres $([ ${PG_VERS_NUM} -ge 93 ] && echo '-k') "$@"
        cat <<-EOF >>"$PGDATA/postgresql.conf"
archive_mode = on
archive_command = 'cd .'
checkpoint_completion_target = 0.9

# Sane logging
logging_collector = on
log_directory = '/tmp'
log_filename = 'pgsql-$PG_BRANCH-$PG_WORKON.log'
log_min_duration_statement = 0
log_autovacuum_min_duration = 0
log_min_messages = info
log_lock_waits = on
log_checkpoints = on
log_temp_files = 0
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d '

# BDR settings
shared_preload_libraries = 'bdr'
pg2q.backtrace_on_internal_error=on


# Other settings
EOF
        if [ ${PG_VERS_NUM} -ge 90 ] && [ ${PG_VERS_NUM} -lt 95 ]; then
            echo "wal_level = hot_standby" >>"$PGDATA/postgresql.conf"
        elif [ ${PG_VERS_NUM} -ge 95 ]; then
            echo "wal_level = logical" >>"$PGDATA/postgresql.conf"
            echo "track_commit_timestamp=on" >>"$PGDATA/postgresql.conf"
        fi
        if [ ${PG_VERS_NUM} -ge 90 ]; then
            echo "hot_standby = on" >>"$PGDATA/postgresql.conf"
            echo "max_wal_senders = 10" >>"$PGDATA/postgresql.conf"
        fi
        if [ ${PG_VERS_NUM} -ge 94 ]; then
            echo "max_replication_slots = 10" >>"$PGDATA/postgresql.conf"
        fi
        if [ ${PG_VERS_NUM} -le 94 ]; then
            echo "checkpoint_segments = 32" >>"$PGDATA/postgresql.conf"
        fi
        cat <<-EOF >>"$PGDATA/pg_hba.conf"
local replication postgres trust
host  replication postgres 127.0.0.1/8 trust
host  replication postgres ::1/128 trust
EOF
        : >/tmp/pgsql-$PG_BRANCH-$PG_WORKON.log start
        pgstart
    }

    pgstop() {
        if [ -n "$1" ]; then
            if pg_ctl status -D tmp_check/t_*$1_data/pgdata &>/dev/null; then
                pg_ctl stop -m fast -D tmp_check/t_*$1_data/pgdata $2
            else
                echo "test PostgreSQL instance \"$1\" is already stopped"
            fi
        else
            if pg_ctl status &>/dev/null; then
                pg_ctl stop -m fast
            else
                echo "PostgreSQL $PG_VERSION ($PG_BRANCH) is already stopped"
            fi
        fi
    }

    pgstart() {
        if [ -n "$1" ]; then
            if ! pg_ctl status -D tmp_check/t_*$1_data/pgdata &>/dev/null; then
                pg_ctl -w -l tmp_check/log/*$1*.log -D tmp_check/t_*$1_data/pgdata start
            else
                echo "test PostgreSQL instance \"$1\" is already started"
            fi
        else
            if ! pg_ctl status &>/dev/null; then
                pg_ctl -w -l /tmp/pgsql-$PG_BRANCH-$PG_WORKON.log start
            else
                echo "PostgreSQL $PG_VERSION ($PG_BRANCH) is already started"
            fi
        fi

    }

    pgrestart() {
        pgstop && pgstart
    }

    pgdeactivate() {
        if [ -n "$PG_OLD_PATH" ]; then
            export PATH=$PG_OLD_PATH
            unset PG_OLD_PATH
        fi
        unset PGSRC PGDATA PGHOST PGDATABASE PGUSER PGPORT PG_BRANCH PG_VERSION PG_WORKON EXTENSION_BRANCH PG_TEST_PORT_DIR
        unset pgdeactivate pgreinit pgstop pgstart pgrestart
    }

    pgpsql() {
        # This function accepts two arguments.
        # the first argument is the `name` of the node we want to connect
        # the second is to specify the `database`, if it's not supplied
        # then it will default to "bdrtest"

        if [ -f "tmp_check/data/postmaster.pid" ]; then
            echo "### Using regression instance ####"
            local POSTMASTER=tmp_check/data/postmaster.pid
            local TESTDB=${1:-''}
        else
            echo "#### Using TAP instance ####"
            local POSTMASTER=(tmp_check/t_*"${1}"_data*/pgdata/postmaster.pid)
            local TESTDB=${2:-"bdrtest"}
        fi

        local TESTPORT=$(awk '{if (FNR == 4) {print $0}}' "${POSTMASTER}")
        local TESTHOST=$(awk '{if (FNR == 5) {print $0}}' "${POSTMASTER}")

        psql -h $TESTHOST -p $TESTPORT -U $USER $TESTDB
    }

    unset usage
}
