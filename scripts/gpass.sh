#!/bin/bash

tr -dc [:lower:][:digit:] < /dev/urandom | head -c 6; echo
tr -dc [:lower:][:digit:][:upper:] < /dev/urandom | head -c 12; echo
