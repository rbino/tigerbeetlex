#!/usr/bin/env sh
set -e

# This script is used to allow building for macos using Zig 0.9.1
# Mainly taken from: https://github.com/tigerbeetle/tigerbeetle/blob/main/scripts/build.sh
# with some modifications due to the fact that here we get invoked as we were the
# zig executable.

# Clean up the args, since build_dot_zig invokes us thinking we're the zig
# executable, so we have to:
# - Remove the `build` subcommand
# - Remove the `--cache-dir` argument and pass the cache dir as a positional
#   argument to the runner
# Perdoname madre por mi Bash loco
for arg do
  shift
  [ "$arg" = "build" ] && continue
  [ "$arg" = "--cache-dir" ] && NEXT_IS_CACHE_DIR=1 && continue
  [ "$NEXT_IS_CACHE_DIR" = 1 ] && CACHE_ROOT=$arg && unset NEXT_IS_CACHE_DIR && continue
  set -- "$@" "$arg"
done

# Determine the operating system:
if [ "$(uname)" = "Linux" ]; then
    ZIG_OS="linux"
else
    ZIG_OS="macos"
fi

target_set="false"
case "$*" in
    *-Dtarget*)
	target_set="true"
	;;
esac

# The ZIG_INSTALL_DIR is set by :build_dot_zig
ZIG_EXE="$ZIG_INSTALL_DIR/zig"

TARGET=""
if [ "$target_set" = "false" ]; then
    # Default to specifying "native-macos" if the target is not provided.
    # See https://github.com/ziglang/zig/issues/10478 (and note there's not a backport to 0.9.2).
    if [ "$($ZIG_EXE targets | grep '"os": "' | cut -d ":" -f 2 | cut -d '"' -f 2)" = "macos" ]; then
	TARGET="-Dtarget=native-macos"
    fi
fi

BUILD_ROOT="./"
GLOBAL_CACHE_ROOT="$HOME/.cache/zig"

# This executes "zig/zig build {args}" using "-target native-{os}" for the build.zig executable.
# Using the {os} directly instead of "native" avoids hitting an abort on macos Ventura.
# TODO The abort was fixed in 0.10 while we're on 0.9. This script can be removed once we update zig.
$ZIG_EXE run ./scripts/build_runner.zig -target native-$ZIG_OS --main-pkg-path $BUILD_ROOT \
    -- $ZIG_EXE $BUILD_ROOT $CACHE_ROOT "$GLOBAL_CACHE_ROOT" $TARGET \
    "$@"
