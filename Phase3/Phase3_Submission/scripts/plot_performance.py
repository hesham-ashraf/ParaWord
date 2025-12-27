#!/usr/bin/env python3
"""
Task 21: Performance Visualization
Generates plots for checkpoint overhead, recovery time, and throughput analysis
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import os

# Set style
plt.style.use('seaborn-v0_8-darkgrid')
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 10

def plot_checkpoint_overhead():
    """Plot checkpoint overhead comparison"""
    print("Generating checkpoint overhead plot...")
    
    try:
        df = pd.read_csv('checkpoint_overhead_results.csv', encoding='utf-16')
        
        # Filter out summary rows
        df = df[df['Configuration'].isin(['Baseline', 'Checkpoint'])]
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
        
        # Plot 1: Execution time comparison
        baseline_data = df[df['Configuration'] == 'Baseline']['ExecutionTime']
        checkpoint_data = df[df['Configuration'] == 'Checkpoint']['ExecutionTime']
        
        positions = [1, 2]
        bp = ax1.boxplot([baseline_data, checkpoint_data], 
                         positions=positions,
                         labels=['No Checkpointing', 'With Checkpointing'],
                         patch_artist=True,
                         showmeans=True)
        
        # Color the boxes
        colors = ['lightblue', 'lightcoral']
        for patch, color in zip(bp['boxes'], colors):
            patch.set_facecolor(color)
        
        ax1.set_ylabel('Execution Time (seconds)', fontsize=12)
        ax1.set_title('Checkpoint Overhead: Execution Time Comparison', fontsize=14, fontweight='bold')
        ax1.grid(True, alpha=0.3)
        
        # Add mean values as text
        ax1.text(1, baseline_data.mean(), f'{baseline_data.mean():.3f}s', 
                ha='center', va='bottom', fontweight='bold')
        ax1.text(2, checkpoint_data.mean(), f'{checkpoint_data.mean():.3f}s', 
                ha='center', va='bottom', fontweight='bold')
        
        # Plot 2: Overhead percentage
        checkpoint_rows = df[df['Configuration'] == 'Checkpoint']
        if len(checkpoint_rows) > 0:
            overhead_values = checkpoint_rows['Overhead'].dropna()
            
            if len(overhead_values) > 0:
                avg_overhead = overhead_values.mean()
                
                ax2.bar(['Checkpoint Overhead'], [avg_overhead], 
                       color='coral', alpha=0.7, edgecolor='black', linewidth=2)
                ax2.axhline(y=10, color='orange', linestyle='--', label='10% threshold')
                ax2.axhline(y=25, color='red', linestyle='--', label='25% threshold')
                
                ax2.set_ylabel('Overhead (%)', fontsize=12)
                ax2.set_title('Average Checkpoint Overhead', fontsize=14, fontweight='bold')
                ax2.legend()
                ax2.grid(True, alpha=0.3, axis='y')
                
                # Add value on bar
                ax2.text(0, avg_overhead + 1, f'{avg_overhead:.2f}%', 
                        ha='center', va='bottom', fontsize=14, fontweight='bold')
        
        plt.tight_layout()
        plt.savefig('../plots/checkpoint_overhead.png', dpi=300, bbox_inches='tight')
        print("  Saved: ../plots/checkpoint_overhead.png")
        plt.close()
        
    except FileNotFoundError:
        print("  Error: checkpoint_overhead_results.csv not found")
    except Exception as e:
        print(f"  Error: {e}")

def plot_recovery_time():
    """Plot recovery time analysis"""
    print("Generating recovery time plot...")
    
    try:
        df = pd.read_csv('recovery_time_results.csv', encoding='utf-16')
        
        # Convert numeric columns
        df['TotalTime'] = pd.to_numeric(df['TotalTime'], errors='coerce')
        df['FailureTime'] = pd.to_numeric(df['FailureTime'], errors='coerce')
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
        
        # Plot 1: Total time by failure injection time
        failure_times = df['FailureTime'].unique()
        failure_times.sort()
        
        avg_times = []
        std_times = []
        for ft in failure_times:
            subset = df[df['FailureTime'] == ft]['TotalTime']
            avg_times.append(subset.mean())
            std_times.append(subset.std())
        
        ax1.errorbar(failure_times, avg_times, yerr=std_times, 
                    marker='o', capsize=5, capthick=2, linewidth=2,
                    markersize=8, label='With Recovery')
        ax1.set_xlabel('Failure Injection Time (seconds)', fontsize=12)
        ax1.set_ylabel('Total Execution Time (seconds)', fontsize=12)
        ax1.set_title('Recovery Time vs Failure Injection Point', fontsize=14, fontweight='bold')
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        # Plot 2: Success rate by failure time
        success_rates = []
        for ft in failure_times:
            subset = df[df['FailureTime'] == ft]
            success_count = len(subset[subset['Correct'] == 'Yes'])
            success_rate = (success_count / len(subset)) * 100 if len(subset) > 0 else 0
            success_rates.append(success_rate)
        
        bars = ax2.bar(failure_times, success_rates, 
                      color='green', alpha=0.7, edgecolor='black', linewidth=2)
        ax2.axhline(y=100, color='red', linestyle='--', label='100% target')
        ax2.set_xlabel('Failure Injection Time (seconds)', fontsize=12)
        ax2.set_ylabel('Success Rate (%)', fontsize=12)
        ax2.set_title('Recovery Success Rate', fontsize=14, fontweight='bold')
        ax2.set_ylim([0, 110])
        ax2.legend()
        ax2.grid(True, alpha=0.3, axis='y')
        
        # Add percentage labels on bars
        for bar, rate in zip(bars, success_rates):
            height = bar.get_height()
            ax2.text(bar.get_x() + bar.get_width()/2., height + 2,
                    f'{rate:.0f}%', ha='center', va='bottom', fontweight='bold')
        
        plt.tight_layout()
        plt.savefig('../plots/recovery_time.png', dpi=300, bbox_inches='tight')
        print("  Saved: ../plots/recovery_time.png")
        plt.close()
        
    except FileNotFoundError:
        print("  Error: recovery_time_results.csv not found")
    except Exception as e:
        print(f"  Error: {e}")

def plot_throughput():
    """Plot throughput with failures"""
    print("Generating throughput analysis plot...")
    
    try:
        df = pd.read_csv('throughput_results.csv', encoding='utf-16')
        
        # Convert numeric columns
        df['ExecutionTime'] = pd.to_numeric(df['ExecutionTime'], errors='coerce')
        df['Throughput_MBps'] = pd.to_numeric(df['Throughput_MBps'], errors='coerce')
        
        scenarios = ['Baseline', '1 Failure', '2 Failures', '3 Failures']
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
        
        # Plot 1: Throughput comparison
        avg_throughput = []
        std_throughput = []
        for scenario in scenarios:
            subset = df[df['Scenario'] == scenario]['Throughput_MBps']
            avg_throughput.append(subset.mean())
            std_throughput.append(subset.std())
        
        x_pos = np.arange(len(scenarios))
        bars = ax1.bar(x_pos, avg_throughput, yerr=std_throughput,
                      color=['green', 'yellow', 'orange', 'red'],
                      alpha=0.7, edgecolor='black', linewidth=2,
                      capsize=5)
        
        ax1.set_xlabel('Scenario', fontsize=12)
        ax1.set_ylabel('Throughput (MB/s)', fontsize=12)
        ax1.set_title('Throughput vs Number of Failures', fontsize=14, fontweight='bold')
        ax1.set_xticks(x_pos)
        ax1.set_xticklabels(scenarios)
        ax1.grid(True, alpha=0.3, axis='y')
        
        # Add values on bars
        for bar, value in zip(bars, avg_throughput):
            height = bar.get_height()
            ax1.text(bar.get_x() + bar.get_width()/2., height + 0.5,
                    f'{value:.2f}', ha='center', va='bottom', fontweight='bold')
        
        # Plot 2: Throughput degradation
        baseline_throughput = avg_throughput[0]
        degradation = []
        for i, tp in enumerate(avg_throughput):
            if i == 0:
                degradation.append(0)
            else:
                deg = ((baseline_throughput - tp) / baseline_throughput) * 100
                degradation.append(deg)
        
        bars2 = ax2.bar(x_pos[1:], degradation[1:],
                       color=['yellow', 'orange', 'red'],
                       alpha=0.7, edgecolor='black', linewidth=2)
        
        ax2.set_xlabel('Scenario', fontsize=12)
        ax2.set_ylabel('Throughput Degradation (%)', fontsize=12)
        ax2.set_title('Performance Degradation with Failures', fontsize=14, fontweight='bold')
        ax2.set_xticks(x_pos[1:])
        ax2.set_xticklabels(scenarios[1:])
        ax2.grid(True, alpha=0.3, axis='y')
        
        # Add values on bars
        for bar, value in zip(bars2, degradation[1:]):
            height = bar.get_height()
            ax2.text(bar.get_x() + bar.get_width()/2., height + 0.5,
                    f'{value:.1f}%', ha='center', va='bottom', fontweight='bold')
        
        plt.tight_layout()
        plt.savefig('../plots/throughput_analysis.png', dpi=300, bbox_inches='tight')
        print("  Saved: ../plots/throughput_analysis.png")
        plt.close()
        
    except FileNotFoundError:
        print("  Error: throughput_results.csv not found")
    except Exception as e:
        print(f"  Error: {e}")

def plot_summary():
    """Create a comprehensive summary plot"""
    print("Generating comprehensive summary plot...")
    
    try:
        # Read all data files
        checkpoint_df = pd.read_csv('checkpoint_overhead_results.csv', encoding='utf-16')
        recovery_df = pd.read_csv('recovery_time_results.csv', encoding='utf-16')
        throughput_df = pd.read_csv('throughput_results.csv', encoding='utf-16')
        
        fig = plt.figure(figsize=(16, 10))
        gs = fig.add_gridspec(2, 3, hspace=0.3, wspace=0.3)
        
        # 1. Checkpoint Overhead
        ax1 = fig.add_subplot(gs[0, 0])
        baseline = checkpoint_df[checkpoint_df['Configuration'] == 'Baseline']['ExecutionTime']
        checkpoint = checkpoint_df[checkpoint_df['Configuration'] == 'Checkpoint']['ExecutionTime']
        ax1.bar(['Baseline', 'Checkpoint'], [baseline.mean(), checkpoint.mean()],
               color=['lightblue', 'lightcoral'], edgecolor='black')
        ax1.set_ylabel('Time (s)')
        ax1.set_title('Checkpoint Overhead', fontweight='bold')
        ax1.grid(True, alpha=0.3, axis='y')
        
        # 2. Recovery Success Rate
        ax2 = fig.add_subplot(gs[0, 1])
        success_count = len(recovery_df[recovery_df['Correct'] == 'Yes'])
        total_count = len(recovery_df)
        success_rate = (success_count / total_count * 100) if total_count > 0 else 0
        ax2.bar(['Recovery'], [success_rate], color='green', edgecolor='black')
        ax2.set_ylim([0, 110])
        ax2.set_ylabel('Success Rate (%)')
        ax2.set_title('Recovery Success Rate', fontweight='bold')
        ax2.axhline(y=100, color='red', linestyle='--', alpha=0.5)
        ax2.grid(True, alpha=0.3, axis='y')
        ax2.text(0, success_rate + 2, f'{success_rate:.1f}%', ha='center', fontweight='bold')
        
        # 3. Throughput by Scenario
        ax3 = fig.add_subplot(gs[0, 2])
        scenarios = ['Baseline', '1 Failure', '2 Failures', '3 Failures']
        throughputs = []
        for scenario in scenarios:
            subset = throughput_df[throughput_df['Scenario'] == scenario]['Throughput_MBps']
            throughputs.append(subset.mean())
        ax3.plot(scenarios, throughputs, marker='o', linewidth=2, markersize=8, color='blue')
        ax3.set_ylabel('Throughput (MB/s)')
        ax3.set_title('Throughput vs Failures', fontweight='bold')
        ax3.tick_params(axis='x', rotation=15)
        ax3.grid(True, alpha=0.3)
        
        # 4. Execution Time Distribution
        ax4 = fig.add_subplot(gs[1, :2])
        for scenario in scenarios:
            subset = throughput_df[throughput_df['Scenario'] == scenario]['ExecutionTime']
            ax4.hist(subset, alpha=0.5, label=scenario, bins=10)
        ax4.set_xlabel('Execution Time (s)')
        ax4.set_ylabel('Frequency')
        ax4.set_title('Execution Time Distribution', fontweight='bold')
        ax4.legend()
        ax4.grid(True, alpha=0.3)
        
        # 5. Performance Summary Table
        ax5 = fig.add_subplot(gs[1, 2])
        ax5.axis('off')
        
        # Calculate summary statistics
        baseline_throughput = throughput_df[throughput_df['Scenario'] == 'Baseline']['Throughput_MBps'].mean()
        checkpoint_overhead = checkpoint_df[checkpoint_df['Configuration'] == 'Checkpoint']['Overhead'].mean()
        
        summary_text = f"""
Performance Summary

Checkpoint Overhead:
  {checkpoint_overhead:.2f}%

Recovery Success:
  {success_rate:.1f}%

Baseline Throughput:
  {baseline_throughput:.2f} MB/s

Avg Execution Time:
  {baseline.mean():.3f}s (no ckpt)
  {checkpoint.mean():.3f}s (with ckpt)
        """
        
        ax5.text(0.1, 0.9, summary_text, transform=ax5.transAxes,
                fontsize=11, verticalalignment='top', fontfamily='monospace',
                bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
        
        plt.suptitle('Phase 3: Resilience & High Availability - Performance Summary',
                    fontsize=16, fontweight='bold', y=0.98)
        
        plt.savefig('../plots/performance_summary.png', dpi=300, bbox_inches='tight')
        print("  Saved: ../plots/performance_summary.png")
        plt.close()
        
    except Exception as e:
        print(f"  Error creating summary plot: {e}")

def main():
    """Main function to generate all plots"""
    print("=" * 50)
    print("Task 21: Performance Visualization")
    print("=" * 50)
    print()
    
    # Create plots directory
    os.makedirs('../plots', exist_ok=True)
    
    # Generate all plots
    plot_checkpoint_overhead()
    plot_recovery_time()
    plot_throughput()
    plot_summary()
    
    print()
    print("=" * 50)
    print("All plots generated successfully!")
    print("=" * 50)
    print("\nGenerated files:")
    print("  - ../plots/checkpoint_overhead.png")
    print("  - ../plots/recovery_time.png")
    print("  - ../plots/throughput_analysis.png")
    print("  - ../plots/performance_summary.png")
    print()

if __name__ == '__main__':
    main()
