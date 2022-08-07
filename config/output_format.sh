#!/usr/bin/env bash

set -e

awk -F'|' \
  '
  {
    result = $3
    gsub(/ /, "", result)
    if (result ~ /^f/)
      printf "\033[1;41m%-*s\033[0m\n", pad_length, $0
    else
      printf $0"\n"
  }

  {
    if (NR == 1)
      pad_length = length($0)
  }
  ' \
| more
