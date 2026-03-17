# Pgenv

This is a personal collection of shell scripts to easily develop and test several PostgreSQL at once.

## Install

Checkout the project somewhere convenient (e.g. `~/prj/pgenv`)

    git clone https://github.com/irionr/pgenv.git ~/prj/pgenv

The PostgreSQL/BDR source trees live in `$HOME/pgsql` by default. This is
controlled by the `SOURCE_DIR` variable in `pgenv-lib.sh`.

Add the following lines to `~/.bashrc` or `~/.zshrc`

    # pgenv
    if [ -r "$HOME/prj/pgenv/pgenv.sh" ] ; then
        . "$HOME/prj/pgenv/pgenv.sh"
    fi

Reload the current shell

    exec bash

## Project structure

    pgenv-lib.sh        # shared library: configuration, helpers, all functions
    pgenv.sh            # interactive shell integration (pgworkon, etc.)
    pull-all.sh         # wrapper → pgenv_pull_all
    clean-all.sh        # wrapper → pgenv_clean_all
    configure-all.sh    # wrapper → pgenv_configure_all
    install-all.sh      # wrapper → pgenv_install_all
    new-branch.sh       # wrapper → pgenv_new_branch

All logic lives in `pgenv-lib.sh` as functions. The individual `*.sh` scripts
are thin wrappers for CLI use. After sourcing `pgenv.sh`, the functions are
also available directly in your shell (e.g. `pgenv_clean_all 17`).

## Configuration

`pgenv-lib.sh` defines two key variables at the top:

| Variable        | Default        | Purpose                                      |
|-----------------|----------------|----------------------------------------------|
| `SOURCE_DIR`    | `$HOME/pgsql`  | Where PostgreSQL/BDR source trees live        |
| `CURRENT_DEVEL` | `19`           | Current development branch major version      |

When a new PostgreSQL major version enters development, bump `CURRENT_DEVEL`.

## Flavors

| Prefix   | Example     | Branch pattern               | Base port |
|----------|-------------|------------------------------|-----------|
| *(none)* | `17`        | `REL_17_STABLE`              | 5400      |
| `PGE`    | `PGE14`     | `2QREL_14_STABLE_dev`        | 7400      |
| `36PGE`  | `36PGE14`   | `2QREL_14_STABLE_3_6`        | 8400      |
| `EDBAS`  | `EDBAS16`   | `EDBAS_16_STABLE`            | 10400     |
| `BDRPG`  | `BDRPG16`   | `BDRPG_16_STABLE`            | 12400     |

Using `master` or the `CURRENT_DEVEL` number resolves to the `master` branch.
Bare flavor names without a version (e.g. `PGE`, `EDBAS`, `BDRPG`) resolve
to the corresponding `*-master` branch.

## Install master version (required)

Initial postgresql checkout

    git clone git://git.postgresql.org/git/postgresql.git $HOME/pgsql/master

> **NOTE:** Optionally, you can also use PGE or EDBAS, clone the repositories in
> `$HOME/pgsql/2QREL-master` or `$HOME/pgsql/EDBAS-master` respectively.

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

    ./configure-all.sh master
    ./install-all.sh master

## Install a stable version (optional)

Add a $VERSION checkout (e.g. 17, 16, etc.)

To use PGE with 3.6 BDR/PGL stack use the `36PGE` prefix (e.g. `36PGE14`, `36PGE15`)
To use PGE with BDR/PGL version 3.7 or later use only the `PGE` prefix (e.g. `PGE14`, `PGE16`)
For EDBAS use the `EDBAS` prefix (e.g. `EDBAS15`, `EDBAS16`)

Optionally set bdr and pglogical environment variables pointing to your
clone of the bdr and pglogical repository.
Add the following lines to `~/.bashrc`

	# github private repos
    export PGL_REPO="$HOME/pgsql/pglogical"
    export BDR_REPO="$HOME/pgsql/bdr"

    ./new-branch.sh $VERSION

Build and install the $VERSION version

    ./configure-all.sh $VERSION
    ./install-all.sh $VERSION

## Upgrade an existing installation

Upgrade all the installed versions

    ./pull-all.sh
    ./clean-all.sh
    ./configure-all.sh
    ./install-all.sh

Upgrade only one version (numeric version or master)

    ./pull-all.sh
    ./clean-all.sh $VERSION
    ./configure-all.sh $VERSION
    ./install-all.sh $VERSION

## Usage

### pgworkon

*Usage:* `pgworkon <flavor><version> [<ticket> [<BDR version>]]`

Activates a PostgreSQL development environment. See the [Flavors](#flavors)
table above for valid prefixes.

The second (optional) argument is the JIRA number (or any other tracking
number). It creates a work directory under `$HOME/work/` with that name and
sets up git worktrees for bdr and pglogical.

The third (optional) argument is the BDR/PGL extension version (e.g. `6`, `5`, `4`,
`3.7`, `3.6`). Defaults to `6`.

Example:

    pgworkon PGE14 BDR-42 4

This creates a worktree in `$HOME/work/BDR-42` using Postgres Extended v14
and BDR v4.

### pgreinit

*Usage:* `pgreinit`

Destroys the current `$PGDATA` and runs `initdb` again with BDR-friendly
defaults. Only available after a `pgworkon` call.

### pgstop, pgstart, pgrestart

Controls the state of the current environment. Only available after a
`pgworkon` call. Accepts an optional test instance name to target a specific
TAP test node instead of the main instance.

### pgdeactivate

Resets the environment and unsets all pgenv variables and functions.

### pgpsql

*Usage:* `pgpsql [<node>] [<database>]`

Connects psql to a running test instance (regression or TAP). For TAP
instances, the first argument is the node name and the second is the database
(defaults to `bdrtest`).

### pgpgbench

*Usage:* `pgpgbench <node> [<pgbench args>] [<database>]`

Same as `pgpsql` but runs `pgbench` instead, with optional pgbench arguments.
