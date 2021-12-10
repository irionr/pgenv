# TO DO , pgstatus does not work yet.
#	pgstatus() {
#	    local PG_DIR="$HOME/work/BDR-670/.pgenv"
#	    local versiondir version bindir datadir
#	    for versiondir in $PG_DIR/data/*
#	    do
#	        version=${versiondir##*/}
#	        bindir="$PG_DIR/versions/$version/bin"
#	        for datadir in $versiondir/*
#	        do
#	            if [ -d "$bindir" ]; then
#	                "$bindir/pg_ctl" -D "$datadir" status | grep PID | sed -n "/pg_ctl:/s//$version: PostgreSQL $($bindir/pg_ctl --version | awk '{print $3}'):/p"
#	            else
#	                echo  "WARNING: datadir $datadir without corresponding executables in $bindir"
#	            fi
#	        done
#	    done
#	}
_pgenv_hook() {
    if [[ -n "$PG_VERSION" ]]
    then
		if [[ "$PG_BRANCH" = dev ]]
		then
		    echo -n "{pgDEV} "
		elif [[ "$PG_BRANCH" =~ _dev$ ]]
		then
			if [[ "$BASE_BRANCH" = master ]]
			then
				echo -n "{m2Q$PG_VERSION}"
			else
				echo -n "{3.72Q$PG_VERSION}"
			fi
		elif [[ "$PG_BRANCH" =~ 3_6$ ]]
		then
		    echo -n "{3.62Q$PG_VERSION}"
		elif [[ "$PG_BRANCH" =~ ^EDBAS ]]
		then
		    echo -n "{EDBAS$PG_VERSION}"
		elif [[ "$PG_BRANCH" =~ ^BDRPG ]]
		then
		    echo -n "{BDRPG$PG_VERSION}"
		else
		    echo -n "{pg$PG_VERSION} "
		fi
    fi
    if [[ -n "$PG_WORKON" ]]
    then
        echo -n  "{$PG_WORKON}"
    fi

}

if ! [[ "$PROMPT_COMMAND" =~ _pgenv_hook ]]; then
    PROMPT_COMMAND="_pgenv_hook;$PROMPT_COMMAND";
fi

pgworkon() {
    local SOURCE_DIR="$HOME/pgsql"
    local CURRENT_DEVEL=15
    local BASE_PORT=5400

    # command the instance  directly when using pgworkon
    # e.g., "pgworkon 13 reinit"
    # if [ -n "$2" ]
    # then
    #     (
    #         pgworkon "$1"
    #         shift
    #         # alias the pg* functions to a more intuitive name
    #         stop(){ pgstop "$@";}
    #         start(){ pgstart "$@";}
    #         restart(){ pgrestart "$@";}
    #         reinit(){ pgreinit "$@";}
    #         "$@"
    #     )
    #     return
    # fi

    usage() {
        [ -n "$1" ] && echo "$1" 1>&2
        echo 1>&2
        echo "usage: $0 pg_version [command]" 1>&2
    }

    case "$1" in
      "")
        usage "ERROR: missing argument"
        return 1
        ;;
      # community
      master|$CURRENT_DEVEL)
        PG_VERSION=$CURRENT_DEVEL
        PG_BRANCH=master
        BASE_BRANCH="REL3_7_STABLE"
        ;;
      1*)
        PG_VERSION="$1"
        PG_BRANCH="REL_${1}_STABLE"
        BASE_BRANCH="REL3_7_STABLE"
        ;;
      # PGE (2QPG)
      m2q1*) # PGE compatible with bdr master (4.0)
        PG_VERSION="${1#m2q}"
        PG_BRANCH="2QREL_${PG_VERSION}_STABLE_dev"
        BASE_BRANCH="master"
        BASE_PORT=8400
        ;;
      372q1*) # PGE compatible with bdr 3.7
        PG_VERSION="${1#372q}"
        PG_BRANCH="2QREL_${PG_VERSION}_STABLE_dev"
        BASE_BRANCH="REL3_7_STABLE"
        BASE_PORT=7400
        ;;
      362q1*) # PGE compatible with bdr 3.6
        PG_VERSION="${1#362q}"
        PG_BRANCH="2QREL_${PG_VERSION}_STABLE_3_6"
        BASE_BRANCH="REL3_6_STABLE"
        BASE_PORT=9400
        ;;
      # EDB Advance Server
      EDBAS-master)
        PG_VERSION=14
        PG_BRANCH="EDBAS-master"
        BASE_BRANCH="REL3_7_STABLE"
        BASE_PORT=10400
        ;;
      EDB1*)
        PG_VERSION="${1#EDB}"
        PG_BRANCH="EDBAS_${PG_VERSION}_STABLE"
        BASE_BRANCH="REL3_7_STABLE"
        BASE_PORT=11400
        ;;
      BDRPG1*)
        PG_VERSION="${1#BDRPG}"
        PG_BRANCH="BDRPG_${PG_VERSION}_STABLE"
        BASE_BRANCH="master"
        BASE_PORT=12400
        ;;
      *)
        PG_VERSION="$1"
        PG_BRANCH="REL${1/./_}_STABLE"
        BASE_BRANCH="REL3_7_STABLE"
        ;;
    esac

    PG_VERS_NUM=${PG_VERSION/./}
    if [ ${PG_VERSION%%.*} -ge 10 ]
    then
        PG_VERS_NUM=${PG_VERS_NUM}0
    fi

    if [ -n "$2" ]
    then
        export PG_WORKON=$2
        local BASE_DIR="$HOME/work/$2"
        local PG_DIR="$BASE_DIR/.pgenv"

        if [ ! -d "$BASE_DIR" ]
        then
            # create a new dev branch or checkout if exists
            pushd $PGL_REPO
            git worktree add -b dev/$2 $BASE_DIR/pgl $BASE_BRANCH ||
				git worktree add  $BASE_DIR/pgl dev/$2
            popd
            pushd $BDR_REPO
            git worktree add -b dev/$2 $BASE_DIR/bdr $BASE_BRANCH ||
				git worktree add  $BASE_DIR/bdr dev/$2
            popd
            $SOURCE_DIR/new-branch.sh $1 $2
            $SOURCE_DIR/configure-all.sh $1 $2
            $SOURCE_DIR/install-all.sh $1 $2
        fi
        cd $BASE_DIR/
    else
        local BASE_DIR="$SOURCE_DIR"
        local PG_DIR="$SOURCE_DIR/.pgenv"
    fi

    local DIR="$SOURCE_DIR/$PG_BRANCH"
    local BINDIR="$PG_DIR/versions/$PG_BRANCH/bin"
    local DATADIR="$PG_DIR/data/$PG_BRANCH/main"
    if [ ! -d "$DIR" ]
    then
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
    export PGPORT=$((BASE_PORT + PG_VERS_NUM))
    export PGHOST=/tmp

    if which dpkg-architecture > /dev/null; then
        # No undo action on pgdeactivate. Having libreadline preloaded
        # shouldn't be of any harm
        if ! [[ "$LD_PRELOAD" =~ 'libreadline.so' ]]
        then
            export LD_PRELOAD=/lib/$(dpkg-architecture -qDEB_BUILD_GNU_TYPE)/libreadline.so.6:$LD_PRELOAD
        fi
    fi

    pgreinit() {
        pgstop
        rm -f /tmp/pgsql-$PG_BRANCH.log
        rm -fr "$PGDATA"
        mkdir -p "$PGDATA"
        initdb -U postgres $([ ${PG_VERS_NUM} -ge 93 ] && echo '-k') "$@"
        cat <<-EOF >> "$PGDATA/postgresql.conf"
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
        if [ ${PG_VERS_NUM} -ge 90 ] && [ ${PG_VERS_NUM} -lt 95 ]
        then
            echo "wal_level = hot_standby" >> "$PGDATA/postgresql.conf"
        elif [ ${PG_VERS_NUM} -ge 95 ]
        then
            echo "wal_level = logical" >> "$PGDATA/postgresql.conf"
            echo "track_commit_timestamp=on" >> "$PGDATA/postgresql.conf"
        fi
        if [ ${PG_VERS_NUM} -ge 90 ]
        then
            echo "hot_standby = on" >> "$PGDATA/postgresql.conf"
            echo "max_wal_senders = 10" >> "$PGDATA/postgresql.conf"
        fi
        if [ ${PG_VERS_NUM} -ge 94 ]
        then
            echo "max_replication_slots = 10" >> "$PGDATA/postgresql.conf"
        fi
        if [ ${PG_VERS_NUM} -le 94 ]
        then
            echo "checkpoint_segments = 32" >> "$PGDATA/postgresql.conf"
        fi
        cat <<-EOF >> "$PGDATA/pg_hba.conf"
local replication postgres trust
host  replication postgres 127.0.0.1/8 trust
host  replication postgres ::1/128 trust
EOF
        :> /tmp/pgsql-$PG_BRANCH.log start
        pgstart
    }

    pgstop() {
        if pg_ctl status &> /dev/null
        then
            pg_ctl stop -m fast
        else
            echo "PostgreSQL $PG_VERSION ($PG_BRANCH) is already stopped"
        fi
    }

    pgstart() {
        if ! pg_ctl status &> /dev/null
        then
            pg_ctl -w -l /tmp/pgsql-$PG_BRANCH.log start
        else
            echo "PostgreSQL $PG_VERSION ($PG_BRANCH) is already started"
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
        unset PGSRC PGDATA PGHOST PGDATABASE PGUSER PGPORT PG_BRANCH PG_VERSION PG_WORKON
        unset pgdeactivate pgreinit pgstop pgstart pgrestart
    }

    unset usage
}
