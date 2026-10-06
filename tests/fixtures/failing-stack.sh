#!/usr/bin/env bash

printf '%s\n' 'Starting failing fixture'
printf '%s\n' 'ERROR: request failed' >&2
printf '%s\n' '    at Widget.run (/workspace/src/widget.js:42:13)' >&2
printf '%s\n' '    at main (/workspace/src/main.js:8:5)' >&2
printf '%s\n' 'Caused by: fixture dependency unavailable' >&2
printf '%s\n' 'Last relevant line: request id fixture-123' >&2
exit 3
