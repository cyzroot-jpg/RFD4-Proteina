#!/bin/bash

cd ..; source ./env.sh; cd -

cd ../test_tools
python3 daily_test.py --gid 2 --cases_list /data/Hpe_share/project/daily_test/blas/1.6.0_sdaa_cases_list.txt
