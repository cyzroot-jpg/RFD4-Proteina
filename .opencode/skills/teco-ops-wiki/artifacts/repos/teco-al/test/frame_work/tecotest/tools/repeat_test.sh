
for ((i=0;i<$1;i++)) do
DNN_ONLY_TEST_PERFORMANCE=1 python3 ../tools/unit_test_v2.py --gid "all" --cases_list $2 --perf_repeat=50 --warm_repeat=3
done
