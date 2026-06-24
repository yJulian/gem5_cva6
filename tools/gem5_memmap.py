#!/usr/bin/env python3
"""
gem5 Memory Map Generator
Parses gem5 configuration files (config.json or config.ini) and outputs a detailed memory map in Markdown.
"""

import os
import sys
import json
import argparse
import configparser

def parse_range_str(s):
    if not s or ':' not in s:
        return None
    try:
        parts = s.split(':')
        if len(parts) == 2:
            return int(parts[0]), int(parts[1])
    except ValueError:
        pass
    return None

def format_size(bytes_val):
    if bytes_val < 1024:
        return f"{bytes_val} B"
    elif bytes_val < 1024 * 1024:
        return f"{bytes_val / 1024:.2f} KiB"
    elif bytes_val < 1024 * 1024 * 1024:
        return f"{bytes_val / (1024 * 1024):.2f} MiB"
    else:
        return f"{bytes_val / (1024 * 1024 * 1024):.2f} GiB"

def extract_from_json_node(node, regions, sys_info):
    if not isinstance(node, dict):
        return
    
    path = node.get("path")
    obj_type = node.get("type", "Unknown")
    
    # Check for range attributes
    for range_key in ['range', 'ranges', 'mem_ranges', 'addr_ranges']:
        if range_key in node:
            val = node[range_key]
            if isinstance(val, list):
                for v in val:
                    r = parse_range_str(v)
                    if r:
                        regions.append({
                            'start': r[0],
                            'end': r[1],
                            'size': r[1] - r[0],
                            'path': path,
                            'type': obj_type,
                            'source_key': range_key
                        })
            elif isinstance(val, str):
                r = parse_range_str(val)
                if r:
                    regions.append({
                        'start': r[0],
                        'end': r[1],
                        'size': r[1] - r[0],
                        'path': path,
                        'type': obj_type,
                        'source_key': range_key
                    })
    
    # Check for pio_addr and pio_size
    pio_addr = None
    pio_size = None
    for k, v in node.items():
        if k == 'pio_addr' or k.endswith('_pio_addr'):
            try:
                pio_addr = int(v)
            except (ValueError, TypeError):
                pass
        elif k == 'pio_size' or k.endswith('_pio_size'):
            try:
                pio_size = int(v)
            except (ValueError, TypeError):
                pass
                
    if pio_addr is not None and pio_size is not None:
        regions.append({
            'start': pio_addr,
            'end': pio_addr + pio_size,
            'size': pio_size,
            'path': path,
            'type': obj_type,
            'source_key': 'pio_addr/pio_size'
        })
        
    # Check for general system properties
    if obj_type == 'System' and path:
        sys_info['mem_mode'] = node.get('mem_mode')
        sys_info['cache_line_size'] = node.get('cache_line_size')
    elif (obj_type == 'RiscvBareMetal' or (path and 'workload' in path)):
        sys_info['bootloader'] = node.get('bootloader')
    elif (obj_type == 'SrcClockDomain' or (path and 'clk_domain' in path)):
        sys_info['clock'] = node.get('clock')

    # Recursively traverse child objects
    for k, v in node.items():
        if isinstance(v, dict):
            extract_from_json_node(v, regions, sys_info)
        elif isinstance(v, list):
            for item in v:
                if isinstance(item, dict):
                    extract_from_json_node(item, regions, sys_info)

def parse_json_config(file_path):
    with open(file_path, 'r') as f:
        data = json.load(f)
    regions = []
    sys_info = {}
    extract_from_json_node(data, regions, sys_info)
    return regions, sys_info

def parse_ini_config(file_path):
    config = configparser.ConfigParser()
    config.read(file_path)
    regions = []
    sys_info = {}
    
    for section in config.sections():
        obj_type = config.get(section, 'type', fallback='Unknown')
        
        # Check ranges
        for range_key in ['range', 'ranges', 'mem_ranges', 'addr_ranges']:
            if config.has_option(section, range_key):
                val = config.get(section, range_key)
                for part in val.split():
                    r = parse_range_str(part)
                    if r:
                        regions.append({
                            'start': r[0],
                            'end': r[1],
                            'size': r[1] - r[0],
                            'path': section,
                            'type': obj_type,
                            'source_key': range_key
                        })
                        
        # Check pio_addr / pio_size
        pio_addr = None
        pio_size = None
        for option in config.options(section):
            if option == 'pio_addr' or option.endswith('_pio_addr'):
                try:
                    pio_addr = int(config.get(section, option))
                except ValueError:
                    pass
            elif option == 'pio_size' or option.endswith('_pio_size'):
                try:
                    pio_size = int(config.get(section, option))
                except ValueError:
                    pass
                    
        if pio_addr is not None and pio_size is not None:
            regions.append({
                'start': pio_addr,
                'end': pio_addr + pio_size,
                'size': pio_size,
                'path': section,
                'type': obj_type,
                'source_key': 'pio_addr/pio_size'
            })
            
        # System info
        if obj_type == 'System':
            sys_info['mem_mode'] = config.get(section, 'mem_mode', fallback=None)
            sys_info['cache_line_size'] = config.get(section, 'cache_line_size', fallback=None)
        elif obj_type == 'RiscvBareMetal' or 'workload' in section:
            sys_info['bootloader'] = config.get(section, 'bootloader', fallback=None)
        elif obj_type == 'SrcClockDomain' or 'clk_domain' in section:
            sys_info['clock'] = config.get(section, 'clock', fallback=None)
            
    return regions, sys_info

def generate_markdown(regions, sys_info, filepath):
    # Group identical ranges
    grouped = {}
    for r in regions:
        key = (r['start'], r['end'])
        if key not in grouped:
            grouped[key] = {
                'start': r['start'],
                'end': r['end'],
                'size': r['size'],
                'objects': []
            }
        grouped[key]['objects'].append(r)
        
    sorted_ranges = sorted(grouped.values(), key=lambda x: x['start'])
    
    lines = []
    lines.append("# gem5 Memory Map")
    lines.append(f"Generated from: `{filepath}`  ")
    lines.append("")
    
    # System Info Section
    lines.append("## System Overview")
    if sys_info:
        if 'clock' in sys_info and sys_info['clock']:
            clk = sys_info['clock']
            # gem5 SrcClockDomain clock can be a list or single value representing tick period in ps
            if isinstance(clk, list):
                clk = clk[0]
            try:
                # convert ps period to MHz
                period_ps = float(clk)
                if period_ps > 0:
                    freq_mhz = 1000000.0 / period_ps
                    lines.append(f"- **Clock Frequency:** {freq_mhz:.2f} MHz (Period: {period_ps} ps)")
                else:
                    lines.append(f"- **Clock Period:** {clk} ps")
            except (ValueError, TypeError):
                lines.append(f"- **Clock Info:** {clk}")
        if 'mem_mode' in sys_info and sys_info['mem_mode']:
            lines.append(f"- **Memory Mode:** `{sys_info['mem_mode']}`")
        if 'cache_line_size' in sys_info and sys_info['cache_line_size']:
            lines.append(f"- **Cache Line Size:** {sys_info['cache_line_size']} B")
        if 'bootloader' in sys_info and sys_info['bootloader']:
            lines.append(f"- **Workload Bootloader (ELF):** `{sys_info['bootloader']}`")
    else:
        lines.append("*No system information found.*")
    lines.append("")
    
    # Summary Table
    lines.append("## Memory Map Table")
    lines.append("| Start Address | End Address | Size | Range (Decimal) | Mapped SimObject(s) | Type |")
    lines.append("|---|---|---|---|---|---|")
    
    for r in sorted_ranges:
        start_hex = f"0x{r['start']:08X}"
        end_hex = f"0x{r['end']:08X}"
        size_str = format_size(r['size'])
        dec_range = f"{r['start']} - {r['end']-1}"
        
        # Deduplicate paths and types to clean up representation if they are the same
        unique_objs = []
        seen = set()
        for obj in r['objects']:
            obj_key = (obj['path'], obj['type'])
            if obj_key not in seen:
                seen.add(obj_key)
                unique_objs.append(obj)

        obj_paths = "<br>".join([f"`{obj['path']}`" for obj in unique_objs])
        obj_types = "<br>".join([f"`{obj['type']}`" for obj in unique_objs])
        
        lines.append(f"| {start_hex} | {end_hex} | {size_str} | {dec_range} | {obj_paths} | {obj_types} |")
        
    lines.append("")
    
    # Visual Layout
    lines.append("## Visual Address Space Layout")
    lines.append("```text")
    lines.append("┌────────────────────────────────────────────────────────┐")
    
    prev_end = None
    for idx, r in enumerate(sorted_ranges):
        if prev_end is not None and r['start'] > prev_end:
            gap = r['start'] - prev_end
            gap_str = format_size(gap)
            lines.append(f"│ [ Gap of {gap_str} ]".ljust(57) + "│")
            lines.append("├────────────────────────────────────────────────────────┤")
            
        start_hex = f"0x{r['start']:08X}"
        end_hex = f"0x{(r['end'] - 1):08X}"
        size_str = format_size(r['size'])
        
        lines.append(f"│ [{start_hex} - {end_hex}] ({size_str})".ljust(57) + "│")
        
        unique_objs = []
        seen = set()
        for obj in r['objects']:
            obj_key = (obj['path'], obj['type'])
            if obj_key not in seen:
                seen.add(obj_key)
                unique_objs.append(obj)
                
        for obj in unique_objs:
            lines.append(f"│   └─ {obj['path']} ({obj['type']})".ljust(57) + "│")
            
        if idx < len(sorted_ranges) - 1:
            lines.append("├────────────────────────────────────────────────────────┤")
            
        prev_end = r['end']
        
    lines.append("└────────────────────────────────────────────────────────┘")
    lines.append("```")
    
    return "\n".join(lines)

def main():
    parser = argparse.ArgumentParser(description="Generate memory map in Markdown from gem5 config.json or config.ini")
    parser.add_argument("config_file", nargs="?", default="m5out/config.json",
                        help="Path to gem5 config file (default: m5out/config.json)")
    parser.add_argument("-o", "--output", help="Path to write the markdown output (default: print to stdout)")
    
    args = parser.parse_args()
    
    if not os.path.exists(args.config_file):
        print(f"Error: Config file '{args.config_file}' not found.", file=sys.stderr)
        sys.exit(1)
        
    ext = os.path.splitext(args.config_file)[1].lower()
    
    if ext == '.json':
        try:
            regions, sys_info = parse_json_config(args.config_file)
        except Exception as e:
            print(f"Error parsing JSON config: {e}", file=sys.stderr)
            sys.exit(1)
    elif ext == '.ini':
        try:
            regions, sys_info = parse_ini_config(args.config_file)
        except Exception as e:
            print(f"Error parsing INI config: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        # Try JSON first, then INI
        try:
            regions, sys_info = parse_json_config(args.config_file)
        except Exception:
            try:
                regions, sys_info = parse_ini_config(args.config_file)
            except Exception as e:
                print(f"Error: Could not parse '{args.config_file}' as JSON or INI: {e}", file=sys.stderr)
                sys.exit(1)
                
    if not regions:
        print("Warning: No memory regions or PIO ranges found in config file.", file=sys.stderr)
        
    markdown_content = generate_markdown(regions, sys_info, args.config_file)
    
    if args.output:
        try:
            with open(args.output, 'w') as f:
                f.write(markdown_content)
            print(f"Memory map written to '{args.output}'")
        except Exception as e:
            print(f"Error writing output to '{args.output}': {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print(markdown_content)

if __name__ == '__main__':
    main()
