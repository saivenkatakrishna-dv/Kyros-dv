#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import glob
import random
import subprocess
from datetime import datetime


############################################################
# Discover tests from testlist.f
############################################################

def discover_tests(testlist):

    tests = []

    fp = open(testlist, "r")

    for line in fp:

        line = line.strip()

        if line == "":
            continue

        if line.startswith("#"):
            continue

        parts = line.split()

        if len(parts) == 2:

            try:
                count = int(parts[1])

                for i in range(count):
                    tests.append(parts[0])

            except:
                tests.append(parts[0])

        else:
            tests.append(parts[0])

    fp.close()

    return tests


############################################################
# Merge Coverage
############################################################

def merge_coverage(scope_dir="./cov_work/scope", merged_name="cov_merged_output"):

    print ""
    print "========================================"
    print "Merging Coverage"
    print "========================================"

    if not os.path.exists(scope_dir):
        print "Coverage directory not found."
        return

    run_dirs = []

    for d in sorted(os.listdir(scope_dir)):

        full = os.path.join(scope_dir, d)

        if not os.path.isdir(full):
            continue

        # Skip merged output if it already exists
        if d == merged_name:
            continue

        # Only include directories that contain at least one UCD file
        ucd_files = glob.glob(os.path.join(full, "*.ucd"))
        if ucd_files:
            run_dirs.append(os.path.abspath(full))

    if len(run_dirs) == 0:
        print "No coverage runs found."
        return

    if not os.path.exists("./cov_files"):
        os.mkdir("./cov_files")

    cmdfile = "./cov_files/cov_merge.cmd"

    fp = open(cmdfile, "w")

    fp.write("merge -out %s " % merged_name)

    for r in run_dirs:
        fp.write(os.path.abspath(r) + " ")

    fp.write("\n")

    fp.write("load -run %s\n" % merged_name)

    fp.write("report_metrics -summary -metrics all -out cov_summary.txt\n")
    fp.write("report_metrics -detail  -metrics all -out cov_detail.txt\n")

    fp.close()
    print ""
    print "Generated IMC command file:"
    print ""

    os.system("cat " + cmdfile)

    print ""
    print "Running IMC..."
    print ""

    subprocess.call(["imc", "-exec", cmdfile])

    print ""
    print "Coverage Merge Completed."
    print ""

############################################################
# Main
############################################################

def main():

    if len(sys.argv) < 3:

        print ""
        print "Usage:"
        print "python regression.py testlist.f MODE=pinaka [1]"
        print ""
        print "Example:"
        print "python regression.py testlist.f MODE=pinaka"
        print "python regression.py testlist.f MODE=pinaka 1"
        print ""

        sys.exit(1)

    testlist = sys.argv[1]

    mode = "pinaka"

    if sys.argv[2].startswith("MODE="):
        mode = sys.argv[2].split("=")[1]

    cov_enable = False

    if len(sys.argv) > 3:
        if sys.argv[3] == "1":
            cov_enable = True

    tests = discover_tests(testlist)

    date = datetime.now().strftime("%d_%m_%Y")

    reg_dir = "Regression_" + date

    if not os.path.exists(reg_dir):
        os.mkdir(reg_dir)

    ########################################################
    # Create one common coverage directory
    ########################################################

    if cov_enable:

        if os.path.exists("./cov_work"):
            subprocess.call(["rm", "-rf", "./cov_work"])

        os.makedirs("./cov_work")

    ########################################################
    # Regression Log
    ########################################################

    logfile = open(os.path.join(reg_dir, "regression.log"), "w")

    logfile.write("SOC REGRESSION REPORT\n")
    logfile.write("=========================================\n\n")

    pass_count = 0
    fail_count = 0
    summary={}

    ########################################################
    # Run all tests
    ########################################################

    for test in tests:

        seed = random.randint(1,99999)

        print ""
        print "========================================="
        print "TEST :", test
        print "MODE :", mode
        print "SEED :", seed

        if cov_enable:
            print "COVERAGE : ENABLED"
        else:
            print "COVERAGE : DISABLED"

        print "========================================="

        test_dir = os.path.join(reg_dir, test + "_" + str(seed))

        if not os.path.exists(test_dir):
            os.makedirs(test_dir)

        cmd = [
            "make",
            "MODE=" + mode,
            "C_TEST=" + test,
            "SEED=" + str(seed)
        ]

        if cov_enable:

            cmd.append("COV=1")
            cmd.append("COV_DIR=./cov_work")

        ret = subprocess.call(cmd)

        if ret == 0:

            result = "PASS"
            pass_count += 1

        else:

            result = "FAIL"
            fail_count += 1

        print "RESULT :", result

        logfile.write("%-35s %-8d %s\n" % (test, seed, result))

        if test not in summary:
           summary[test] = []

        summary[test].append((seed, result))

    ########################################################
    # Finish Regression
    ########################################################

    logfile.write("\n")
    logfile.write("------------------------------------------\n")
    logfile.write("TOTAL PASS : %d\n" % pass_count)
    logfile.write("TOTAL FAIL : %d\n" % fail_count)
    logfile.write("------------------------------------------\n")

    logfile.write("\n")
    logfile.write("=========================================\n")
    logfile.write("REGRESSION SUMMARY\n")
    logfile.write("=========================================\n\n")

    for test in sorted(summary.keys()):

        logfile.write("%s\n" % test)

        seed_list = []

        for seed, result in summary[test]:
            seed_list.append("%d(%s)" % (seed, result))

        logfile.write("Seeds : %s\n\n" % ", ".join(seed_list))

    logfile.close()

    print ""
    print "=========================================="
    print "Regression Finished"
    print "=========================================="
    print "PASS :", pass_count
    print "FAIL :", fail_count
    print ""

    ########################################################
    # Merge Coverage
    ########################################################
    print ""
    print "========================================="
    print "REGRESSION SUMMARY"
    print "========================================="

    for test in sorted(summary.keys()):

        print test

        seed_list = []

        for seed, result in summary[test]:
            seed_list.append("%d(%s)" % (seed, result))

        print "Seeds :", ", ".join(seed_list)
        print ""

    if cov_enable:

        merge_coverage()


############################################################
# Start
############################################################

if __name__ == "__main__":
    main()
