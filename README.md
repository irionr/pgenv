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

    git clone git://git.postgresql.org/git/postgresql.git $HOME/pgsql/master

> **NOTE:** Optionaly, you can use also PGE or EPAS, clone the repositories in the
> $HOME/pgsql/2QPG-master or $HOME/pgsql/EDBAS-master respectivley.


On Rocky linux, required packages:

	sudo dnf install readline-devel openssl-devel libxml2-devel tcl-devel bison flex libcurl-devel 

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

To use PGE with 3.6 BDR/PGL stack use the 36PGE prefix(e.g. 36PGE10, 36PGE11...)
To use PGE with BDR/PGL version 3.7 or later use only the PGE prefix(e.g. PGE11, PGE14...)
For EDBAS use "EPAS" prefix (e.g. EPAS12, EPAS15...)

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

*Usage: pgworkon {FLAVOR}{VERSION} [[{ticket number}] [{BDR version}]]

There are 4 Postgres flavors that can be used + 1 for the
almost EOL BDR3.6, with the first argument:
    PG*
    PGE*
    3.6PGE*
    EPAS*
    BDRPG*
The second (optional) argument is the JIRA number (or any other
traking number), it creates a work directory with this name.
The third  (optional) argument is the extension version (BDR/PGL)

e.g.

`pgworkon PGE14 BDR-42 4`

This command will create a worktree in the `$HOME/work` directory
named `BDR-42` that will use Postgres Extended v14 and BDR v4.


### pgreinit

*Usage: pgreinit*

destroy the current *$PGDATA* and run *initdb* again, , available only after a *pgworkon* call

### pgstop, pgstart, pgrestart

controls the state of the current environment, available only after a *pgworkon* call

### pgdeactivate

reset the state and exit from any environment

### pgstatus

list the running instances
