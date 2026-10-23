#!/bin/bash
set -e

cases_list=/data/hpe_data/testcase/test_cases_list/pr_list.txt
if [ $# -ge 1 ]; then
    cases_list=$1
fi


cd ..; source ./env.sh; cd -

cd ../build
rm -rf log; rm -rf *.json; rm -rf *.xlsx; rm -rf *.log; rm -rf *.tar.gz;
python3 ../test_tools/pr_test.py $cases_list

