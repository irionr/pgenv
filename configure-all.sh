#!/bin/bash

set -e

cd ~/pgsql

ARGS=

if which port > /dev/null
then
    ARGS+=" --with-libraries=/opt/local/lib --with-includes=/opt/local/include"
elif which brew > /dev/null
then
    INCLUDES=
    LIBS=
    for pkg in openssl readline libxml2
    do
        prefix=$(brew --prefix $pkg)
        if [ -n "$INCLUDES" ]; then INCLUDES+=:; fi
            INCLUDES+="$prefix/include"
        if [ -n "$LIBS" ]; then LIBS+=:; fi
            LIBS+="$prefix/lib"
            export PATH="$prefix/bin:$PATH"
    done
    ARGS+=" --with-tclconfig=/usr/local/opt/tcl-tk/lib"
    ARGS+=" --with-includes=$INCLUDES"
    ARGS+=" --with-libraries=$LIBS"
fi

ARGS+=" --with-tcl --with-libxml --with-openssl"
DEBUG_ARGS="--enable-depend --enable-cassert --enable-debug"

# Enable tap tests if IPC::Run is available
if [ -n "$(perldoc -lm IPC::Run)" ]
then
    DEBUG_ARGS+=" --enable-tap-tests"
fi

CFLAGS="-ggdb -Og -g3 -fno-omit-frame-pointer"

# openSUSE and SUSE have tclConfig.sh in /usr/lib64 for x86_64 machines
if [ -f "/etc/SuSE-release" ] && [ "$(uname -m)" == 'x86_64' ]
then
    ARGS+=" --with-tclconfig=/usr/lib64"
fi

if (which ccache && which clang ) > /dev/null
then
    ARGS+=" CC='ccache clang -Qunused-arguments -fcolor-diagnostics'"
fi

if [ -n "$2" ];
then
    for a in dev master $(ls -rd 2Q*) $(ls -rd REL*) $(ls -rd EDB*)
    do
        # if the directory doesn't exist skip it
        [ -d $a ] || continue

        # if an argument is provided install only that version
        [ -n "$1" ] && [ "$1" != "$a" ] && [ "REL${1/./_}_STABLE" != "$a" ] && [ "REL_${1}_STABLE" != "$a" ] && [ "2QREL_${1#2Q}_STABLE_3_6" != "$a" ] && [ "2QREL_${1#2qm}_STABLE_dev" != "$a" ] && [ "EDBAS_${1#EDB}_STABLE" != "$a" ] && continue

        pushd $a
		git worktree add -b dev/$2 $HOME/work/$2/dev/$a
        popd

        instdir="$HOME/work/$2/.pgenv/versions/$a"
        pushd $HOME/work/$2/dev/$a
        ./configure --prefix="$instdir" ${DEBUG_ARGS} ${ARGS} CFLAGS="$CFLAGS"
        popd
    done
else
    for a in dev master $(ls -rd 2Q*) $(ls -rd *REL*) $(ls -rd EDB*)
    do
        # if the directory doesn't exist skip it
        [ -d $a ] || continue

        # if an argument is provided install only that version
        [ -n "$1" ] && [ "$1" != "$a" ] && [ "REL${1/./_}_STABLE" != "$a" ] && [ "REL_${1}_STABLE" != "$a" ] && [ "2QREL_${1#2Q}_STABLE_3_6" != "$a" ] && [ "2QREL_${1#2qm}_STABLE_dev" != "$a" ] && [ "EDBAS_${1#EDB}_STABLE" != "$a" ] && continue

        instdir="$HOME/.pgenv/versions/$a"
        pushd $a
        ./configure --prefix="$instdir" ${DEBUG_ARGS} ${ARGS} CFLAGS="$CFLAGS"
        popd
    done
fi
