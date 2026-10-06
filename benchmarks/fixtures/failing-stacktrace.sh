#!/usr/bin/env bash

printf '%s\n' 'Running failing benchmark fixture'
printf '%s\n' 'ERROR: expected true but received false' >&2
printf '%s\n' '    at Widget.validate (/workspace/src/widget.js:42:13)' >&2
printf '%s\n' '    at runCase (/workspace/tests/widget.test.js:18:5)' >&2
printf '%s\n' 'Caused by: AssertionError at /workspace/src/assert.js:7:2' >&2
printf '%s\n' 'Last relevant line: benchmark failure id bench-001' >&2
exit 7
