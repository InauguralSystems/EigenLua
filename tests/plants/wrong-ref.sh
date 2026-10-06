#!/usr/bin/env bash
if [[ ${1:-} == -v ]]; then
  printf '%s\n' 'Lua 5.4.8  Copyright (C) 1994-2025 Lua.org, PUC-Rio'
  exit 0
fi
printf 'wrong-ref\n'
exit 0
