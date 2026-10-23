#! /bin/bash
set -e

cases_dir=/data/hpe_data/testcase/daily_test
case_info=/data/hpe_data/case_info
ctime=$(date "+%Y_%m_%d-%H_%M_%S")

out_file=../custom_daily_${ctime}
xml_result_file=${out_file}.xml
xls_result_file=${out_file}.xlsx
cases_info_file=${case_info}/case_info.json
log_file=${out_file}.log

cd ..; source ./env.sh; cd -

cd ../build
export DNN_RESERVE_DATA=1
export DNN_USE_CASE_INFO=1
./demo --gid=0 --gtest_filter=custom_* --cases_dir=${cases_dir} --gtest_output=xml:${xml_result_file} >  $log_file
python3 ../tools/result_parse.py $xml_result_file $xls_result_file $cases_info_file
chmod 777 ${case_info}/*
