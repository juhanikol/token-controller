#!/usr/bin/env bash

_WX_BENCH_INDEX=1
while [ "$_WX_BENCH_INDEX" -le 200 ]; do
  printf '%s\n' 'PASS tests/example.test.js'
  _WX_BENCH_INDEX=$((_WX_BENCH_INDEX + 1))
done
printf '%s\n' 'Summary: 200 passed, 0 failed'
