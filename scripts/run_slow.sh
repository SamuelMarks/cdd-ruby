#!/usr/bin/env bash
if [ -n "$RUN_SLOW_TESTS" ] && [ "$RUN_SLOW_TESTS" != "0" ] && [ "$RUN_SLOW_TESTS" != "false" ]; then
    exec "$@"
else
    echo "Skipping slow test (set RUN_SLOW_TESTS=1 to run): $*"
    exit 0
fi
