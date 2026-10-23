#! /bin/bash
set -e
# default build only dnn, now only support dnn
TECO_AL=ON

usage () {
    echo "USAGE: sh build.sh <options>"
    echo
    echo "OPTIONS:"
    echo "      -h, --help                      Print usage."
    echo "      -f, --filter {\"op1;...;opn\"}  Build specific operations seperated by ;."
    echo
}

while [ $# != 0 ]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        -f | --filter)
            shift
            BUILD_SPECIFIC_OP=${1}
            shift
            ;;
    esac
done

if [[ ${TECOTEST_READY_TO_BUILD} != "ON" ]]; then
    echo "please source env.sh before build.sh."
    exit -1
fi

# thirdparty
python3 deps.py
cd test_proto; sh ./generate.sh; cd -

# build 
build_path=build
if [[ -d ${build_path} ]]; then
    rm ${build_path}/* -rf
elif [[ -a ${build_path} ]]; then
    rm ${build_path}
    mkdir ${build_path}
else
    mkdir ${build_path}
fi

pushd ${build_path}
    cmake \
    -DBUILD_SPECIFIC_OP=${BUILD_SPECIFIC_OP} \
    ..
    make -j32
popd
