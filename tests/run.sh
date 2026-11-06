#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BIN="$ROOT/out/linux-x86_64/debug/bin/machfuck"
TMP=$(mktemp -d)
cleanup() {
    rm -rf "$TMP"
}
trap cleanup EXIT HUP INT TERM

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

expect_byte() {
    program=$1
    expected=$2
    "$BIN" "$ROOT/tests/programs/$program" >"$TMP/output"
    actual=$(od -An -tu1 "$TMP/output" | tr -d ' ')
    [ "$actual" = "$expected" ] || fail "$program: expected byte $expected, got $actual"
}

expect_failure() {
    program=$1
    message=$2
    if "$BIN" "$ROOT/tests/programs/$program" >"$TMP/output" 2>"$TMP/error"; then
        fail "$program unexpectedly succeeded"
    fi
    grep -q "$message" "$TMP/error" || fail "$program: missing diagnostic '$message'"
}

mach build "$ROOT" -a machfuck

expect_byte simple-output.bf 65
expect_byte arithmetic.bf 10
expect_byte loop.bf 65
expect_byte zero-loop.bf 0
expect_byte nested-loops.bf 8
expect_byte wrapping.bf 0
expect_byte comments.bf 65

printf Z | "$BIN" "$ROOT/tests/programs/input-output.bf" >"$TMP/output"
[ "$(od -An -tu1 "$TMP/output" | tr -d ' ')" = 90 ] || fail "input/output"
"$BIN" "$ROOT/tests/programs/input-output.bf" </dev/null >"$TMP/output"
[ "$(od -An -tu1 "$TMP/output" | tr -d ' ')" = 0 ] || fail "EOF"

expect_failure unmatched-open.bf "unmatched opening bracket"
expect_failure unmatched-close.bf "unmatched closing bracket"
expect_failure left-boundary.bf "moved left"

awk 'BEGIN { for (i = 0; i < 30000; i++) printf ">" }' >"$TMP/right-boundary.bf"
if "$BIN" "$TMP/right-boundary.bf" >"$TMP/output" 2>"$TMP/error"; then
    fail "right boundary unexpectedly succeeded"
fi
grep -q "moved right" "$TMP/error" || fail "right boundary diagnostic"

"$BIN" --help | grep -q "Usage:" || fail "--help"
"$BIN" --help | grep -q "machfuck compile program.bf" || fail "--help compile usage"
"$BIN" --help | grep -q -- "--target TARGET" || fail "--help target option"
"$BIN" --help | grep -q "windows-x86_64" || fail "--help target list"
"$BIN" --version | grep -q "Machfuck 1.0.0" || fail "--version"
if "$BIN" >"$TMP/output" 2>"$TMP/error"; then fail "missing source unexpectedly succeeded"; fi
grep -q "no source file" "$TMP/error" || fail "missing source diagnostic"
if "$BIN" "$TMP/absent.bf" >"$TMP/output" 2>"$TMP/error"; then fail "absent file unexpectedly succeeded"; fi
grep -q "cannot read" "$TMP/error" || fail "absent file diagnostic"

if PATH=/nonexistent "$BIN" compile "$ROOT/tests/programs/loop.bf" >"$TMP/output" 2>"$TMP/error"; then
    fail "compile without Mach unexpectedly succeeded"
fi
grep -q "Mach compiler is not installed" "$TMP/error" || fail "missing Mach diagnostic"
if "$BIN" compile "$ROOT/tests/programs/loop.bf" --target unsupported >"$TMP/output" 2>"$TMP/error"; then
    fail "unsupported target unexpectedly succeeded"
fi
grep -q "unsupported target" "$TMP/error" || fail "unsupported target diagnostic"

cd "$TMP"
"$BIN" compile "$ROOT/tests/programs/loop.bf" --target linux-x86_64 --output "$TMP/native"
"$TMP/native/loop" >"$TMP/output"
[ "$(od -An -tu1 "$TMP/output" | tr -d ' ')" = 65 ] || fail "transpiled loop"

"$BIN" compile "$ROOT/tests/programs/input-output.bf" --output "$TMP/native"
printf Z | "$TMP/native/input-output" >"$TMP/output"
[ "$(od -An -tu1 "$TMP/output" | tr -d ' ')" = 90 ] || fail "transpiled input/output"

for target in \
    linux-x86_64 \
    linux-arm64 \
    linux-riscv64 \
    windows-x86_64 \
    darwin-x86_64 \
    darwin-aarch64
do
    "$BIN" compile "$ROOT/tests/programs/loop.bf" --target "$target" --output "$TMP/$target"
done

echo "All Machfuck tests passed."
