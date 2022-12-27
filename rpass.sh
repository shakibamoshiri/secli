#!/bin/bash

set -eu

_max="${1:?a number is needed}";
_counter=0;

while (( ++_counter < $_max )); do
    echo $(tr -dc [:lower:][:digit:] < /dev/urandom | head -c 8) $(tr -dc [:lower:][:digit:][:upper:] < /dev/urandom | head -c 16)
done
