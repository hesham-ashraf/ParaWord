import os
import csv
import matplotlib.pyplot as plt

# --------------------------
# Paths setup
# --------------------------
BASE_DIR = os.path.dirname(__file__)
PLOTS_DIR = os.path.join(os.path.dirname(BASE_DIR), "plots")

os.makedirs(PLOTS_DIR, exist_ok=True)

# --------------------------
# Helper function to read CSV
# --------------------------
def read_scaling_csv(path):
    ranks = []
    times = []
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            ranks.append(int(row["ranks"]))
            times.append(float(row["time"]))
    return ranks, times

# ==========================================================
# STRONG SCALING
# ==========================================================
strong_csv_path = os.path.join(BASE_DIR, "strong_scaling.csv")

if not os.path.exists(strong_csv_path):
    print("❌ strong_scaling.csv not found! Run the strong-scaling script first.")
else:
    ranks_s, times_s = read_scaling_csv(strong_csv_path)

    T1 = times_s[0]
    speedup = [T1 / t for t in times_s]
    efficiency = [s / p for s, p in zip(speedup, ranks_s)]

    # ---- Speedup Plot ----
    plt.figure()
    plt.plot(ranks_s, speedup, marker="o", linewidth=2)
    plt.xlabel("MPI Ranks")
    plt.ylabel("Speedup (T1 / Tp)")
    plt.title("MPI Strong Scaling — Speedup")
    plt.grid(True)
    plt.savefig(os.path.join(PLOTS_DIR, "mpi_speedup.png"), dpi=200)

    # ---- Efficiency Plot ----
    plt.figure()
    plt.plot(ranks_s, efficiency, marker="s", linewidth=2)
    plt.xlabel("MPI Ranks")
    plt.ylabel("Efficiency (Speedup / p)")
    plt.title("MPI Strong Scaling — Efficiency")
    plt.grid(True)
    plt.savefig(os.path.join(PLOTS_DIR, "mpi_efficiency.png"), dpi=200)

    print("✅ Strong scaling plots generated!")


# ==========================================================
# WEAK SCALING
# ==========================================================
weak_csv_path = os.path.join(BASE_DIR, "weak_scaling.csv")

if not os.path.exists(weak_csv_path):
    print("❌ weak_scaling.csv not found! Run the weak-scaling script first.")
else:
    ranks_w, times_w = read_scaling_csv(weak_csv_path)

    # ---- Weak Scaling Plot ----
    plt.figure()
    plt.plot(ranks_w, times_w, marker="o", linewidth=2)
    plt.xlabel("MPI Ranks")
    plt.ylabel("Runtime (seconds)")
    plt.title("MPI Weak Scaling — Runtime vs Ranks")
    plt.grid(True)
    plt.savefig(os.path.join(PLOTS_DIR, "mpi_weak_scaling.png"), dpi=200)

    print("✅ Weak scaling plot generated!")


# ==========================================================
# LATENCY & BANDWIDTH
# ==========================================================
lat_bw_path = os.path.join(BASE_DIR, "lat_bw_results.txt")

if not os.path.exists(lat_bw_path):
    print("❌ lat_bw_results.txt not found! Run latency_bandwidth first.")
else:
    msg_sizes = []
    latencies = []
    bandwidths = []

    with open(lat_bw_path) as f:
        for line in f:
            if line.startswith("#") or line.strip() == "":
                continue
            parts = line.split()
            msg_sizes.append(int(parts[0]))
            latencies.append(float(parts[1]))
            bandwidths.append(float(parts[2]) / (1024 * 1024))  # MB/s

    # ---- Latency Plot ----
    plt.figure()
    plt.plot(msg_sizes, latencies, marker="o", linewidth=2)
    plt.xscale("log")
    plt.xlabel("Message Size (bytes)")
    plt.ylabel("Latency (seconds)")
    plt.title("MPI Latency vs Message Size")
    plt.grid(True)
    plt.savefig(os.path.join(PLOTS_DIR, "mpi_latency.png"), dpi=200)

    # ---- Bandwidth Plot ----
    plt.figure()
    plt.plot(msg_sizes, bandwidths, marker="s", linewidth=2)
    plt.xscale("log")
    plt.xlabel("Message Size (bytes)")
    plt.ylabel("Bandwidth (MB/s)")
    plt.title("MPI Bandwidth vs Message Size")
    plt.grid(True)
    plt.savefig(os.path.join(PLOTS_DIR, "mpi_bandwidth.png"), dpi=200)

    print("✅ Latency & Bandwidth plots generated!")


print("\n🎉 All MPI plots saved in:", PLOTS_DIR)
