cmake_minimum_required(VERSION 3.12)

project(demo)

set(CMAKE_CXX_STANDARD 14) # GoogleTest requires at least C++14
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(THIRDPARTY_DIR ${PROJECT_SOURCE_DIR}/thirdparty)
include_directories(${THIRDPARTY_DIR}/protobuf/include)
link_directories(${THIRDPARTY_DIR}/protobuf/lib)
link_directories(${THIRDPARTY_DIR}/protobuf/lib64)
include_directories(${THIRDPARTY_DIR}/googletest/include)
link_directories(${THIRDPARTY_DIR}/googletest/lib)
link_directories(${THIRDPARTY_DIR}/googletest/lib64)

enable_testing()
include(GoogleTest)

set(DEVICE_ARCH_PATH zoo)

if(BUILD_SPECIFIC_OP)
    foreach(ITEM ${BUILD_SPECIFIC_OP})
        message(STATUS "BUILD_SPECIFIC_OP: ${ITEM}")
    endforeach()
endif()

#execute_process(COMMAND python ${CMAKE_CURRENT_SOURCE_DIR}/test_proto/type_convert.py)
find_package(Python3 COMPONENTS Interpreter)
find_package(PythonInterp)

if(Python3_FOUND)
    if(BUILD_SPECIFIC_OP)
        execute_process(
            COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tools/register_op.py zoo tecoal ${BUILD_SPECIFIC_OP}
        )
    else()
        execute_process(
            COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tools/register_op.py zoo tecoal
        )
    endif()
elseif(PYTHONINTERP_FOUND)
    if(BUILD_SPECIFIC_OP)
        execute_process(
            COMMAND ${PYTHON_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tools/register_op.py zoo tecoal ${BUILD_SPECIFIC_OP}
        )
    else()
        execute_process(
            COMMAND ${PYTHON_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tools/register_op.py zoo tecoal
        )
    endif()
else()
    message(FATAL_ERROR "Neither Python3 nor Python2 interpreter found. Please install Python to continue.")
endif()


#set source
file(GLOB_RECURSE PROTO_SOURCE ${PROJECT_SOURCE_DIR}/test_proto/*.cc)
file(GLOB_RECURSE SRC_SOURCE ${PROJECT_SOURCE_DIR}/src/*.cpp)

file(GLOB_RECURSE DEVICE_SOURCE ${PROJECT_SOURCE_DIR}/src/device/cuda/*.cpp)
list(REMOVE_ITEM SRC_SOURCE ${DEVICE_SOURCE})

set(TECOAL_TESTSUITE_SOURCE)
set(CASE_PATH ${PROJECT_SOURCE_DIR}/${DEVICE_ARCH_PATH}/tecoal)
file(GLOB TECOAL_CASE_SOURCE ${CASE_PATH}/*.cpp)
if(BUILD_SPECIFIC_OP)
    foreach(SPECIFIC_OP ${BUILD_SPECIFIC_OP})
        file(GLOB_RECURSE OP_SOURCE "${CASE_PATH}/${SPECIFIC_OP}/*.cpp")
        list(APPEND TECOAL_TESTSUITE_SOURCE ${OP_SOURCE})
    endforeach()
else()
    file(GLOB_RECURSE TECOAL_TESTSUITE_SOURCE "${CASE_PATH}/*.cpp")
endif()

set(PROJECT_INCLUDE ${PROJECT_SOURCE_DIR})
include_directories(
    ${PROJECT_INCLUDE}
    ${PROJECT_SOURCE_DIR}/src
    ${PROJECT_SOURCE_DIR}/test_proto)

set(BASE_INCLUDE /opt/tecoai/include)
set(BASE_LIB /opt/tecoai/lib64)

set(TECOAL_INCLUDE ${PROJECT_SOURCE_DIR}/../../../interface/include)
set(TECOAL_LIB ${PROJECT_SOURCE_DIR}/../../../build/lib)

include_directories(${TECOAL_INCLUDE} ${BASE_INCLUDE})

add_executable(${PROJECT_NAME} 
               main.cpp 
               ${SRC_SOURCE} 
               ${PROTO_SOURCE} 
               ${TECOAL_CASE_SOURCE}
               ${TECOAL_TESTSUITE_SOURCE})
               
find_library(SDAART_LIBRARY NAMES sdaart PATHS /opt/tecoai/lib64)
target_link_libraries(${PROJECT_NAME} ${SDAART_LIBRARY})
find_library(SDPTI_LIBRARY NAMES sdpti PATHS /opt/tecoai/lib64)
target_link_libraries(${PROJECT_NAME} ${SDPTI_LIBRARY})
find_library(TECOAL_LIBRARY NAMES tecoal PATHS ${TECOAL_LIB})
target_link_libraries(${PROJECT_NAME} ${TECOAL_LIBRARY})

target_link_libraries(${PROJECT_NAME} stdc++fs)
target_link_libraries(${PROJECT_NAME} libprotobuf.a libgtest.a)
target_link_libraries(${PROJECT_NAME} stdc++ dl stdc++fs rt pthread)

set_property(TARGET ${PROJECT_NAME} PROPERTY CXX_STANDARD 14)
