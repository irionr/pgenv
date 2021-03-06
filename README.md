# Pgenv

This is a personal collection of shell scripts to easily develop and test several PostgreSQL at once.

## Install

Checkout the project in `$HOME/pgsql`

    git clone https://github.com/irionr/pgenv.git $HOME/pgsql

Add the following lines to `~/.bashrc`


    # pgenv
    if [ -r "$HOME/pgsql/pgenv.sh" ] ; then
        . "$HOME/pgsql/pgenv.sh"
    fi

Reload the current shell

    exec bash

## Install master version (required)

Initial postgresql checkout

    git clone git://git.postgresql.org/git/postgresql.git $HOME/pgsql/PG-master

> **NOTE:** Optionaly, you can use also 2QPG or EDBAS, clone the repositories in the
> $HOME/pgsql/2QPG-master or $HOME/pgsql/EDBAS-master respectivley.

In Ubuntu, install these packages, which are necessary for configure-all.sh

    sudo apt-get install tcl-dev libssl-dev build-essential bison flex \
        libreadline-dev libxml2-dev

If you use openSUSE, you must install these packages:

    sudo zypper in -t pattern devel_C_C++
    sudo zypper in tcl-devel libxml2-devel readline-devel libopenssl-devel

If you use Archlinux, please be sure that these packages are installed:

    sudo pacman -S tcl libxml2 openssl bison flex base-devel

Build and install the development head version

    cd ~/pgsql
    ./configure-all.sh master
    ./install-all.sh master

## Install a stable version (optional)

Add a $VERSION checkout (e.g. 9.4, 9.3, etc...)

To use 2ndQuadrant PG with 3.6 BDR/PGL stack use the 2Q prefix(e.g. 2Q10, 2Q11...)
To use 2ndQuadrant PG with 3.7 BDR/PGL stack use the 2qm prefix(e.g. 2qm11, 2qm12...)
For EDBAS use "EDB" prefix (e.g. EDB12, EDB13...)

    cd ~/pgsql
    ./new-branch.sh $VERSION

Build and install the $VERSION version

    cd ~/pgsql
    ./configure-all.sh $VERSION
    ./install-all.sh $VERSION

# Upgrade an existing installation

Upgrade all the installed versions

    cd ~/pgsql
    ./pull-all.sh
    ./clean-all.sh
    ./configure-all.sh
    ./install-all.sh

Upgrade only one version (numeric version or master)

    cd ~/pgsql
    ./pull-all.sh
    ./clean-all.sh $VERSION
    ./configure-all.sh $VERSION
    ./install-all.sh $VERSION

## Usage

### pgworkon

*Usage: pgworkon VERSION [ticket number]*

set the environment to use the specific version, if a *ticket number* is specified, then create a working directory in the "$HOME/work" by using git worktrees for the selected postgres, pglogical and bdr versions.
For pglogical and bdr you need to have the repositories locally and set the environment variables "$PGL_REPO" and "$BDR_REPO" to the respective paths.

For example *pgworkon 2qm13 BDR-100* will create a BDR-100 directory with 2QPG13 checkout on the 2QREL_13_STABLE_dev branch.
And it will also create pgl and bdr directories checked out on the new "dev/BDR-100" branch pointing to latest master.

### pgreinit

*Usage: pgreinit*

destroy the current *$PGDATA* and run *initdb* again, , available only after a *pgworkon* call

### pgstop, pgstart, pgrestart

controls the state of the current environment, available only after a *pgworkon* call

### pgdeactivate

reset the state and exit from any environment

### pgstatus

list the running instances
