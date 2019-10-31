#!/bin/bash

# Script author: Patrick Lavin
# This is a script for running CENTRAL_ADD and CENTRAL_CAS with a varying number of
# threads. You can also choose to bind every thread to the same physical cpu with
# the -o option. Display help with -h.

# The script would prefer to use likwid-pin to pin threads, but it will use
# numactl as a backup or nothing if it is unable to find either

# This script can be run from this directory. It assumes you have built in
# circustent/build

usage () {
     echo "Usage: $0 [-p MAX_PE] [-a algo] [-i iter] [-o]"
     echo "  p: Run with 1 up to MAX_PE pe's (default=1)"
     echo "  a: Either ADD or CAS (default=ADD)"
     echo "  i: Number of iterations (default=10000)"
     echo "  o: If specified, bind all procs to same physical cpu (core 1)"
     echo "  h: Display this message"
}

get_cpus () {
    echo
    # if $1 is 0, place nothing in var
    # if $1 is 1, and $2 is unset, return 0
    # if $1 is 1, and $1 is set, return 0-N
}

#################################
#        Parse Arguments        #
#################################

MAX_PE=DEFAULT
INSTR=DEFAULT
ITER=DEFAULT
ONEPE=0
ONEPE_STR=OFF

while getopts ":p:a:i:oh" opt; do
  case ${opt} in
    p ) MAX_PE=$OPTARG
      ;;
    a ) INSTR=$OPTARG
      ;;
    i ) ITER=$OPTARG
      ;;
    o ) ONEPE=1 ONEPE_STR=ON
      ;;
    h ) usage
        exit
      ;;
    \? ) usage
         exit
      ;;
  esac
done

if [ "$INSTR" = "DEFAULT" ]; then
    INSTR=ADD
fi

if [ "$ITER" = "DEFAULT" ]; then
    ITER=$((10**5))
fi

if [ "$MAX_PE" = "DEFAULT" ]; then
    MAX_PE=1
fi

#################################
# Detect thread-pinning command #
#################################

USE_LIKWID=0
USE_NUMACTL=0
PINNING_STR=None
PIN_CMD=

if command -v likwid-pin >/dev/null 2>&1;
then
    USE_LIKWID=1
    PINNING_STR=likwid-pin
    PIN_CMD="likwid-pin -q -c N:"
elif command -v numactl >/dev/null 2>&1;
then
    USE_NUMACTL=1
    PINNING_STR=numactl
    PIN_CMD="numactl --physcpubind="
fi

#################################
#         Run benchmark         #
#################################

echo "=========================="
echo "Benchmark:  CENTRAL_$INSTR"
echo "Num PEs:    1..$MAX_PE"
echo "Iterations: $ITER"
echo "Pinning:    $PINNING_STR"
echo -e "One PE?:    $ONEPE_STR"
echo "=========================="
echo -e "PEs\tGAMS"

CPUS=0

FIXED_OPTS="-m 1 -i $ITER -b CENTRAL_$INSTR"

if [ $ONEPE -eq 1 ];
then
    CPUS=0
    for p in `seq 1 $MAX_PE`;
    do
        echo -ne "$p\t"
        $PIN_CMD$CPUS ../build/src/CircusTent/circustent -p $p $FIXED_OPTS | tail -n 2 | head -n 1 | cut -d' ' -f6
    done
else
    for p in `seq 1 $MAX_PE`;
    do
        CPUS="0-$(($p-1))"
        echo -ne "$p\t"
        $PIN_CMD$CPUS ../build/src/CircusTent/circustent -p $p $FIXED_OPTS | tail -n 2 | head -n 1 | cut -d' ' -f6
    done

fi
