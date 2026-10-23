#!/bin/bash
set -e

cases_list=/data/hpe_data/testcase/self_test_case.txt
if [ $# -ge 1 ]; then
    op_name=$1
fi

cd ..; source ./env.sh; cd -

cd ../build
if [ $# -eq 0 ];then
    USE_MAX_NUM=0 python3 ../test_tools/pr_test.py $cases_list
else
    USE_MAX_NUM=0 python3 ../test_tools/pr_test.py $cases_list $op_name
fi
