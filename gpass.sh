#!/bin/bash

tr -dc [:lower:][:digit:] < /dev/urandom | head -c 8; echo
tr -dc [:lower:][:digit:][:upper:] < /dev/urandom | head -c 16; echo
