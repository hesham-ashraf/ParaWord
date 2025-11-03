import matplotlib.pyplot as plt
import os

# Your real performance data
threads = [1, 2, 4, 8]
speedup = [0.0003078, 0.0004916, 0.0011707, 0.0015493]
efficiency = [0.0003078, 0.0002458, 0.0002927, 0.0001937]

# Ensure the 'plots' directory exists
if not os.path.exists('plots'):
    os.makedirs('plots')

# --------- SPEEDUP PLOT ---------
plt.figure(figsize=(8, 6))
plt.plot(threads, speedup, marker='o', label='Speedup', linewidth=2)
plt.xlabel('Number of Threads')
plt.ylabel('Speedup (Tₛ / Tₚ)')
plt.title('Speedup vs Number of Threads')
plt.grid(True, linestyle='--', alpha=0.6)
plt.legend()
plt.tight_layout()

# Save the plot in the 'plots' directory
plt.savefig('plots/speedup_plot.png')
plt.show()

# --------- EFFICIENCY PLOT ---------
plt.figure(figsize=(8, 6))
plt.plot(threads, efficiency, marker='s', label='Efficiency', linewidth=2, color='orange')
plt.xlabel('Number of Threads')
plt.ylabel('Efficiency (Speedup / Threads)')
plt.title('Efficiency vs Number of Threads')
plt.grid(True, linestyle='--', alpha=0.6)
plt.legend()
plt.tight_layout()

# Save the plot in the 'plots' directory
plt.savefig('plots/efficiency_plot.png')
plt.show()

print("✅ Plots saved in the 'plots' folder: speedup_plot.png and efficiency_plot.png")
