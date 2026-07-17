#!/usr/bin/env python3

import sys

DEFAULT_BASE_MIN = 0x80010000
DEFAULT_WORDS = 32768   # 32K word entries per B0/B1/B2/B3

def usage():
    print("Usage:")
    print("  python3 split_mem.py input.mem output_prefix [base_hex] [num_words]")
    print("")
    print("Example:")
    print("  python3 split_mem.py atomic_16275.mem program_data 0x8001FA88 32768")
    sys.exit(1)

if len(sys.argv) < 3:
    usage()

input_file = sys.argv[1]
output_prefix = sys.argv[2]

user_base = None
if len(sys.argv) >= 4:
    user_base = int(sys.argv[3], 16)

num_words = DEFAULT_WORDS
if len(sys.argv) >= 5:
    num_words = int(sys.argv[4])

mem = {}
markers = []
addr = 0

with open(input_file, "r") as f:
    for line in f:
        line = line.strip()

        if line == "" or line.startswith("//"):
            continue

        if line.startswith("@"):
            addr = int(line[1:], 16)
            markers.append(addr)
            continue

        for b in line.split():
            mem[addr] = int(b, 16)
            addr += 1

# ---------------------------------------------------------
# Select base address
# ---------------------------------------------------------
if user_base is not None:
    base = user_base
else:
    # Auto-pick first non-text/data region after 0x80010000
    candidates = [x for x in markers if x >= DEFAULT_BASE_MIN]

    if len(candidates) == 0:
        print("ERROR: No data marker found above 0x%08x" % DEFAULT_BASE_MIN)
        print("Markers found:")
        for m in markers:
            print("  @%08x" % m)
        sys.exit(1)

    base = candidates[0]

print("Using DATA BASE = 0x%08x" % base)
print("Number of words = %d" % num_words)

# ---------------------------------------------------------
# Split into byte banks
# For word at address A:
#   B0 = MEM[A+0]
#   B1 = MEM[A+1]
#   B2 = MEM[A+2]
#   B3 = MEM[A+3]
# ---------------------------------------------------------
b0_file = output_prefix + "_B0.hex"
b1_file = output_prefix + "_B1.hex"
b2_file = output_prefix + "_B2.hex"
b3_file = output_prefix + "_B3.hex"

word_file = output_prefix + ".hex"

with open(b0_file, "w") as f0, \
     open(b1_file, "w") as f1, \
     open(b2_file, "w") as f2, \
     open(b3_file, "w") as f3, \
     open(word_file, "w") as fw:

    for i in range(num_words):
        a = base + (i * 4)

        b0 = mem.get(a + 0, 0)
        b1 = mem.get(a + 1, 0)
        b2 = mem.get(a + 2, 0)
        b3 = mem.get(a + 3, 0)

        f0.write("%02x\n" % b0)
        f1.write("%02x\n" % b1)
        f2.write("%02x\n" % b2)
        f3.write("%02x\n" % b3)

        fw.write("%02x%02x%02x%02x\n" % (b3, b2, b1, b0))

print("Generated:")
print("  " + b0_file)
print("  " + b1_file)
print("  " + b2_file)
print("  " + b3_file)
print("  " + word_file)
