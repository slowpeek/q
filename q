#!/usr/bin/env bash

# MIT license (c) 2022 https://github.com/slowpeek
# Homepage: https://github.com/slowpeek/q

set -eu

SCRIPT_VERSION=0.1+git

t_red=$'\e[31m'
t_yellow=$'\e[33m'
t_reset=$'\e(B\e[m'
verb=2

_log() {
    (( verb < $1 )) && return
    echo "$2" "${@:3}" >&2
}

log_warn() { _log 2 "${t_yellow}q:${t_reset}" "$@"; }
log_err() { _log 1 "${t_red}q:${t_reset}" "$@"; }

bye() {
    log_err "$@"
    exit 1
}

version() {
    echo "q $SCRIPT_VERSION"
    exit
}

usage() {
    cat <<'EOF'
Usage: q [options] [--] command [command options]

q runs a command into background redirecting all its output into
/dev/null. Essentially, it is such one-liner

    exec "$@" &>/dev/null &

wrapped in checks so in case of a problem with the command, there is
some feedback.

The command could be either a path or a name to be looked for in PATH.

Options:
-h, --help                 Show usage
-q                         Suppress warnings
-V, --version              Show version

Homepage: https://github.com/slowpeek/q
EOF

    exit 0
}

check_dir() {
    local canon
    canon=$(realpath -sm "$1" 2>/dev/null) || bye "$1: what a mess"

    local base=/
    [[ ! $canon == /*/* ]] || base=${canon%/*}

    IFS=/ read -ra base <<< "${base:1}"

    local path='' t
    for t in "${base[@]}"; do
        path+=/$t

        [[ -d $path ]] || bye "$1: no such file"
        [[ -x $path ]] || bye "$canon: $path/ is not reachable"
    done
}

check_executable_file() {
    [[ -e "$1" ]] || bye "$1: no such file"
    [[ -f "$1" ]] || bye "$1: not a regular file"
    [[ -x "$1" ]] || bye "$1: not executable"

    # If an executable file is not readable, there are two cases: it
    # could be either a binary file or a script. Binary files are no
    # problem, but scripts can't be executed. There is no easy way to
    # check which case is it ahead of running. Let's just emit a
    # warning.

    [[ -r "$1" ]] ||
        log_warn "$1: not readable, would not run if it is a script"
}

check_command() {
    local path
    path=$(type -P -- "$1" 2>/dev/null) ||
        bye "$1: there is no such command in PATH"

    check_executable_file "$path"
}

main() {
    (( $# )) || usage

    case $1 in
        -h|--help)
            usage ;;
        -q)
            ((--verb)) || verb=1
            shift ;;
        -V|--version)
            version ;;
        --)
            shift ;;
        -*)
            bye "$1: unknown option" ;;
    esac

    [[ -n "${1-}" ]] || bye 'empty command'

    if [[ $1 == */* ]]; then
        check_dir "$1"
        check_executable_file "$1"
    else
        check_command "$1"
    fi

    exec "$@" &>/dev/null &
}

[[ ! ${BASH_SOURCE[0]} == "$0" ]] || main "$@"
