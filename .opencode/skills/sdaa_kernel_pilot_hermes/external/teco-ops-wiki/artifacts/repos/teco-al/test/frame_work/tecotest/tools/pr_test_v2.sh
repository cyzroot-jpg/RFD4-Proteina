#!/bin/bash
set -e

cases_list=/data/Hpe_share/tecoal_long-term_stability/testsuite/case_list_ci.txt

cd ..; source ./env.sh; cd -

cd ../build
rm -rf log; rm -rf *.json; rm -rf *.xlsx; rm -rf *.log; rm -rf *.tar.gz;
export DNN_CHECK_ALL_MEM=1

if [ $# -ge 1 ]; then
    python3 ../test_tools2/pr_test_v2.py --cases_list=$cases_list --bench_xlsx=$1
else
    python3 ../test_tools2/pr_test_v2.py --cases_list=$cases_list
fi

# baseline: /data/Hpe_share/tecoal_long-term_stability/testsuite/benchmark_2.5Ghz.xlsx 

