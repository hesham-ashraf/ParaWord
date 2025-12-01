#!/bin/bash
set -e

exe="../src/word_count_mpi"
input="../src/sample2.txt"

echo "ranks,time" > strong_scaling.csv

for p in 1 2 4 8; do
    echo "Running with $p ranks..."
    # Extract the time value from the line: "Elapsed time (max over ranks): X seconds"
    t=$(mpirun -n $p $exe "$input" | grep "Elapsed time" | awk '{print $6}')
    echo "$p,$t" >> strong_scaling.csv
done

echo "Strong-scaling results saved to scripts/strong_scaling.csv"
