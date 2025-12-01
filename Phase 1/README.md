# ParaWord

ParaWord is a small C++ project that provides sequential and parallel word-counting programs and a script to plot performance results.

## Repository layout

- `src/` — source files and example text inputs
  - `src/word_count_sequential.cpp` — sequential word count implementation
  - `src/word_count_parallel.cpp` — parallel word count implementation (uses threads)
  - `src/sample.txt`, `src/sample2.txt` — sample input files
- `word_count_seq` — (optional) prebuilt sequential binary (if present)
- `word_count_parallel` — (optional) prebuilt parallel binary (if present)
- `scripts/plot_results.py` — script to visualize performance results
- `data/` — (optional) directory for output/benchmark CSVs

## Goals / Description

The project demonstrates how to implement and compare sequential and parallel word-count algorithms in C++. It includes example inputs and a plotting script to visualize speedup.

## Build

You can compile the programs with `g++` (requires C++17 and pthread for the parallel version):

```bash
# build sequential
g++ -O2 -std=c++17 -o word_count_seq src/word_count_sequential.cpp

# build parallel (uses pthreads)
g++ -O2 -std=c++17 -pthread -o word_count_parallel src/word_count_parallel.cpp
```

If prebuilt binaries `word_count_seq` or `word_count_parallel` exist at the repo root, you can use them directly.

## Run / Examples

Run the sequential program on a sample file:

```bash
./word_count_seq src/sample.txt
```

Run the parallel program (if it accepts a thread count argument; common usage shown below — replace N with number of threads):

```bash
# Example: run with 4 threads
./word_count_parallel src/sample.txt 4
```

If the binaries expect different CLI flags, check the program's help output (e.g., `./word_count_parallel --help`).

## Benchmarking and plotting

Use `scripts/plot_results.py` to visualize results. It requires Python 3 and `matplotlib`:

```bash
python3 -m pip install --user matplotlib
python3 scripts/plot_results.py
```

The script expects CSV or data files in `data/` by default — check the script for exact input names and adjust accordingly.

## Benchmark results (example)

Below is an example of benchmark results from running both the sequential and parallel implementations on a sample file:

| Threads | Parallel Time (s) | Speedup (S = Tₛ/Tₚ) | Efficiency (E = S/p) |
| ------- | ----------------: | ------------------: | -------------------: |
| 1       |         0.0514395 |           0.0003078 |            0.0003078 |
| 2       |         0.0322048 |           0.0004916 |            0.0002458 |
| 4       |         0.0135224 |           0.0011707 |            0.0002927 |
| 8       |         0.0102167 |           0.0015493 |            0.0001937 |

**Notes on the results:**
- The parallel time decreases as thread count increases (up to a point).
- Speedup is calculated as $S = T_{\text{sequential}} / T_{\text{parallel}}$.
- Efficiency is calculated as $E = S / p$, where $p$ is the number of threads.
- Real-world results may vary based on hardware, input size, and system load.

## Notes and assumptions

- Assumes a Linux environment with `g++` installed.
- Assumes the parallel implementation uses pthreads; adjust build flags if it uses another threading method.

