#! /bin/bash
set -e
#set -x

# default build not build unittest
BUILD_TEST=OFF

# default build release type
CMAKE_BUILD_TYPE=Release

# default do not build with VERBOSE=1
BUILD_VERBOSE=OFF

usage () {
    echo "USAGE: ./build.sh <options>"
    echo
    echo "OPTIONS:"
    echo "      -h, --help                      Print usage."
    echo "      -f, --filter {\"op1;...;opn\"}  Build specific operations seperated by ;."
    echo "      --test {on/off}                 Build unittest(default not build unittest)."
    echo "      --debug                         Build debug type(default build release type)."
    echo "      --build_verbose                 Build with VERBOSE=1 and 1 thread(default with 32 threads)."
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
        --test)
            shift
            case "$1" in
                on)
                    BUILD_TEST=ON
                    shift
                    ;;
                off)
                    BUILD_TEST=OFF
                    shift
                    ;;
                *)
                    echo "-- Unknown options for --test ${1}, only support on or off, use -h or --help"
                    usage
                    exit -1
                    ;;
            esac
            ;;
        --debug)
            CMAKE_BUILD_TYPE=DEBUG
            shift
            ;;
        --build_verbose)
            BUILD_VERBOSE=ON
            shift
            ;;
        *)
            echo "-- Unknown options ${1}, use -h or --help"
            usage
            exit -1
            ;;
    esac
done

if [[ ${TECO_READY_TO_BUILD} != "ON" ]]; then
    echo "please source env.sh before build.sh."
    exit -1
fi

# create build directory
if [[ -d build ]]; then
    rm build/* -rf
elif [[ -a build ]]; then
    rm build
    mkdir build
else
    mkdir build
fi


# build tecoal
pushd build
    cmake \
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} \
    -DBUILD_SPECIFIC_OP=${BUILD_SPECIFIC_OP} \
    -DBUILD_TEST=${BUILD_TEST} \
    ..

    if [ "${BUILD_VERBOSE}" == "ON" ]; then
        make -j1 VERBOSE=1
    else
        make -j32
    fi
popd

