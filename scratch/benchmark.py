#!/usr/bin/env python3
import subprocess
import time
import os
import sys

# Define configuration
RISCV_PATH = "/home/julian/gem5_cva6/toolchain/xpack-riscv-none-elf-gcc-14.2.0-1"
REPO_DIR = "/home/julian/gem5_cva6"
CVA6_DIR = os.path.join(REPO_DIR, "cva6")
GEM5_DIR = os.path.join(REPO_DIR, "gem5")

THREADS_TO_TEST = [1, 4, 8, 16]
RESULTS = {}

def run_cmd(cmd, cwd=REPO_DIR, env=None):
    print(f"Running: {cmd} (in {cwd})")
    # Merge environments if needed
    run_env = os.environ.copy()
    if env:
        run_env.update(env)
    
    # We use subprocess.run and throw error on failure
    result = subprocess.run(cmd, shell=True, cwd=cwd, env=run_env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        print(f"Error executing command: {cmd}")
        print("STDOUT:")
        print(result.stdout)
        print("STDERR:")
        print(result.stderr)
        raise RuntimeError(f"Command failed with exit code {result.returncode}")
    return result.stdout, result.stderr

def benchmark():
    # Ensure RISCV environment variable is set
    env = {"RISCV": RISCV_PATH}
    
    for threads in THREADS_TO_TEST:
        print(f"\n==================================================")
        print(f"  BENCHMARKING WITH {threads} THREAD(S)")
        print(f"==================================================")
        
        # 1. Compile Verilator model
        print("Step 1: Compiling Verilator CVA6 model...")
        verilator_cmd = f"make verilate-core TRACE_FAST=1 NUM_THREADS={threads} -j8"
        start_verilate = time.time()
        run_cmd(verilator_cmd, cwd=CVA6_DIR, env=env)
        verilate_time = time.time() - start_verilate
        print(f"-> Verilation took {verilate_time:.2f} seconds.")
        
        # 2. Build gem5
        print("Step 2: Rebuilding gem5.opt...")
        scons_cmd = "scons build/RISCV/gem5.opt -j8"
        start_scons = time.time()
        run_cmd(scons_cmd, cwd=GEM5_DIR)
        scons_time = time.time() - start_scons
        print(f"-> gem5 build/link took {scons_time:.2f} seconds.")
        
        # 3. Run Dhrystone simulation
        print("Step 3: Running Dhrystone simulation...")
        gem5_cmd = "build/RISCV/gem5.opt ../configs/cva6/run_rtl.py --binary ../scratch/dhrystone.elf"
        start_sim = time.time()
        stdout, stderr = run_cmd(gem5_cmd, cwd=GEM5_DIR)
        sim_time = time.time() - start_sim
        print(f"-> Simulation finished in {sim_time:.2f} seconds.")
        
        # Extract simulated ticks if present
        simulated_ticks = None
        for line in stdout.splitlines():
            if "Total simulated ticks" in line:
                try:
                    simulated_ticks = int(line.split(":")[-1].strip())
                except ValueError:
                    pass
        
        RESULTS[threads] = {
            "verilate_time": verilate_time,
            "scons_time": scons_time,
            "sim_time": sim_time,
            "ticks": simulated_ticks
        }

    # Print results summary
    print("\n\n==================================================")
    print("               BENCHMARK RESULTS")
    print("==================================================")
    
    # Generate Markdown Table
    md_table = []
    md_table.append("| Threads | Verilation Time (s) | Gem5 Build Time (s) | Dhrystone Sim Time (s) | Speedup (vs 1 Thread) | Simulated Ticks |")
    md_table.append("|---------|---------------------|---------------------|------------------------|-----------------------|-----------------|")
    
    base_sim_time = RESULTS[1]["sim_time"]
    
    for threads in THREADS_TO_TEST:
        res = RESULTS[threads]
        speedup = base_sim_time / res["sim_time"]
        ticks_str = f"{res['ticks']:,}" if res["ticks"] else "N/A"
        md_table.append(
            f"| {threads:<7} | {res['verilate_time']:<19.2f} | {res['scons_time']:<19.2f} | {res['sim_time']:<22.2f} | {speedup:<21.2f}x | {ticks_str:<15} |"
        )
        
    for row in md_table:
        print(row)
        
    # Write report file
    report_path = os.path.join(REPO_DIR, "scratch", "benchmark_report.md")
    with open(report_path, "w") as f:
        f.write("# CVA6 Verilator Thread Scaling Benchmark Report\n\n")
        f.write("This report compares the performance of CVA6 RTL simulation in gem5 using different Verilator thread counts.\n\n")
        f.write("## Host Configuration\n")
        # Get processor info
        try:
            nprocs = subprocess.check_output("nproc", shell=True, text=True).strip()
            f.write(f"- **CPU Threads Available:** {nprocs}\n")
        except Exception:
            pass
        f.write("\n## Results\n\n")
        for row in md_table:
            f.write(row + "\n")
        f.write("\n## Discussion\n")
        f.write("Increasing the thread count partitions the Verilator C++ model across multiple threads. However, performance scaling depends on:\n")
        f.write("1. **Design Size:** Small designs have high thread synchronization overhead that may offset the execution gains.\n")
        f.write("2. **Core/Thread count on Host:** Hardware resources limits.\n")
        
    print(f"\nReport written to {report_path}")

if __name__ == "__main__":
    benchmark()
