#!/usr/bin/env python3
import sys
import os
import re

def parse_stats(file_path):
    stats = {}
    if not os.path.exists(file_path):
        return None
    
    # Matches key, value, and optional description
    # Example: "simTicks                                      9840000                       # Number of ticks..."
    pattern = re.compile(r"^([a-zA-Z0-9_\.:]+)\s+([+-]?[0-9]*\.?[0-9]+(?:[eE][+-]?[0-9]+)?|nan)")
    
    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("----------"):
                continue
            match = pattern.match(line)
            if match:
                key, val = match.groups()
                try:
                    if '.' in val or 'e' in val.lower():
                        stats[key] = float(val)
                    else:
                        stats[key] = int(val)
                except ValueError:
                    stats[key] = val
    return stats

def main():
    if len(sys.argv) < 3:
        print("Usage: compare_stats.py <stats_file_1> <stats_file_2> [label_1] [label_2]")
        print("Example: ./tools/compare_stats.py m5out_accel/stats.txt m5out_accel_l2/stats.txt Accel Accel_L2")
        sys.exit(1)

    file1 = sys.argv[1]
    file2 = sys.argv[2]
    
    label1 = sys.argv[3] if len(sys.argv) > 3 else os.path.dirname(file1) or "Run 1"
    label2 = sys.argv[4] if len(sys.argv) > 4 else os.path.dirname(file2) or "Run 2"

    stats1 = parse_stats(file1)
    stats2 = parse_stats(file2)

    if stats1 is None:
        print(f"Error: Could not open/parse {file1}")
        sys.exit(1)
    if stats2 is None:
        print(f"Error: Could not open/parse {file2}")
        sys.exit(1)

    # Core statistics we want to compare
    metrics = [
        ("Simulation Ticks", "simTicks", "{:,}"),
        ("Host Real-Time (sec)", "hostSeconds", "{:.3f}"),
        ("Simulated Cycles", "system.cpu.numCycles", "{:,}"),
        ("System Clock Period (ticks)", "system.clk_domain.clock", "{:,}"),
        ("L2 Cache Tag Accesses", "system.l2cache.tags.tagAccesses", "{:,}"),
        ("L2 Cache Data Accesses", "system.l2cache.tags.dataAccesses", "{:,}"),
        ("L2 Cache Replacements", "system.l2cache.replacements", "{:,}"),
        ("Memory Bus Snoops", "system.membus.snoops", "{:,}"),
    ]

    # Dynamically look for any other interesting cache/bus/accel metrics present in either run
    extra_keys = set(stats1.keys()) | set(stats2.keys())
    
    # We can add dynamic search patterns if we want to show L2 statistics
    for key in sorted(extra_keys):
        if any(term in key for term in ["l2cache", "accel.dma", "accel.pio"]) and not any(key == m[1] for m in metrics):
            # Format counts as int/float dynamically
            metrics.append((key, key, "{}"))

    # Print the table header
    print(f"| Metric / Stat Key | {label1} | {label2} | Difference (L2 vs No-L2) |")
    print("| :--- | :---: | :---: | :---: |")

    for desc, key, fmt in metrics:
        val1 = stats1.get(key, "-")
        val2 = stats2.get(key, "-")
        
        # Format values
        v1_str = fmt.format(val1) if isinstance(val1, (int, float)) else str(val1)
        v2_str = fmt.format(val2) if isinstance(val2, (int, float)) else str(val2)
        
        diff_str = "-"
        if isinstance(val1, (int, float)) and isinstance(val2, (int, float)):
            diff = val2 - val1
            percent = (diff / val1 * 100) if val1 != 0 else 0
            sign = "+" if diff > 0 else ""
            diff_str = f"{sign}{fmt.format(diff)} ({sign}{percent:.2f}%)"
            
        # Only print if at least one file has the metric
        if val1 != "-" or val2 != "-":
            print(f"| {desc} | {v1_str} | {v2_str} | {diff_str} |")

if __name__ == "__main__":
    main()
