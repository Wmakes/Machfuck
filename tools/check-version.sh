#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "usage: tools/check-version.sh VERSION [MACHFUCK_BINARY]" >&2
    exit 2
fi

requested=$1
manifest=$(awk -F '"' '/^version[[:space:]]*=/ { print $2; exit }' mach.toml)

if [ -z "$manifest" ]; then
    echo "version check: mach.toml has no project version" >&2
    exit 1
fi

if [ "$requested" != "$manifest" ]; then
    echo "version check: requested version '$requested' does not match mach.toml version '$manifest'" >&2
    exit 1
fi

if [ "$#" -eq 2 ]; then
    binary_version=$($2 --version)
    expected="Machfuck $manifest"
    if [ "$binary_version" != "$expected" ]; then
        echo "version check: binary reports '$binary_version', expected '$expected'" >&2
        exit 1
    fi
fi

echo "Version $manifest is consistent."
