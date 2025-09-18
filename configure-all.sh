#!/bin/bash

set -e

ARGS=

if which port >/dev/null; then
    ARGS+=" --with-libraries=/opt/local/lib --with-includes=/opt/local/include"
elif which brew >/dev/null; then
    INCLUDES=
    LIBS=
    for pkg in openssl readline libxml2; do
        prefix=$(brew --prefix $pkg)
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
DEBUG_ARGS="--enable-depend --enable-cassert --enable-debug "
### unused args
# --enable-coverage

# Enable tap tests if IPC::Run is available
if [ -n "$(perldoc -lm IPC::Run)" ]; then
    DEBUG_ARGS+=" --with-perl --enable-tap-tests"
fi

#CFLAGS+=" --sysroot=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
CFLAGS+=" -Wall -Wextra -Wuninitialized -Wint-conversion -Wno-unused-parameter -Wno-sign-compare"
CFLAGS+=" -ggdb -Og -g3 -fno-omit-frame-pointer -Wno-missing-field-initializers "
# use -O0 to see optimized values with gdb/lvm

# openSUSE and SUSE have tclConfig.sh in /usr/lib64 for x86_64 machines
if [ -f "/etc/SuSE-release" ] && [ "$(uname -m)" == 'x86_64' ]; then
    ARGS+=" --with-tclconfig=/usr/lib64"
fi

if (which ccache && which clang) >/dev/null; then
    ARGS+=" CC='ccache clang -Qunused-arguments -fcolor-diagnostics'"
fi

if [ -n "$2" ]; then
    BASE_DIR="$HOME/work/$2"
else
    BASE_DIR="$HOME/pgsql"
fi

pushd $BASE_DIR

for a in $(ls -rd *STABLE*); do
    # if the directory doesn't exist skip it
    [ -d $a ] || continue

    # if an argument is provided install only that version
    [ -n "$1" ] &&
        [ "$1" != "$a" ] &&
        [ "REL${1/./_}_STABLE" != "$a" ] &&
        [ "REL_${1}_STABLE" != "$a" ] &&
        [ "2QREL_${1#362q}_STABLE_3_6" != "$a" ] &&
        [ "2QREL_${1#PGE}_STABLE_dev" != "$a" ] &&
        [ "EDBAS_${1#EDBAS}_STABLE" != "$a" ] &&
        [ "BDRPG_${1#BDRPG}_STABLE" != "$a" ] &&
        continue

    instdir="$BASE_DIR/.pgenv/versions/$a"
	printf "\n\n\n\n"
    pushd $a
    printf "Running configure with the following arguments: --prefix=$instdir ${DEBUG_ARGS} ${ARGS} CFLAGS=$CFLAGS CPPFLAGS=$CPPFLAGS\n"
    ./configure --prefix="$instdir" ${DEBUG_ARGS} ${ARGS} CFLAGS="$CFLAGS" CPPFLAGS="$CPPFLAGS"
    # return in the $BASE_DIR and remain there
    popd
	printf "\n\n\n\n"
done
