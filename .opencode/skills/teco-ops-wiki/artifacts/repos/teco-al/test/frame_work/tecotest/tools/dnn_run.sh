#!/bin/bash
set -e
if [ $# -lt 1 ]; then
    exit 1
fi

cd ..; source ./env.sh; cd -

cases_list=$1
if [ $# -eq 1 ]; then
cd ../test_tools
python3 daily_test.py --gid 0,1,2,3 --al_type dnn --cases_list $cases_list --cases_info_dir /data/case_info/
else
op_name=$2
cd ../test_tools
python3 daily_test.py --gid 0,1,2,3 --al_type dnn --cases_list $cases_list --op_name $op_name --cases_info_dir /data/case_info/
fi
