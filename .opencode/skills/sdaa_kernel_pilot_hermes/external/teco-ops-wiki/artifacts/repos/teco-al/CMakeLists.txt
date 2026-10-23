cmake_minimum_required(VERSION 3.10.2)

# set the compile output path
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set(CMAKE_C_COMPILER "tecocc")
set(CMAKE_CXX_COMPILER "tecocc")

# set cxx to std11 standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

project(tecoal)

add_compile_options(-Werror -DUSE_EXPERIMENTAL_SDAA_API)
#add_compile_options(-debug)

set(PROJECT_INCLUDE ${PROJECT_SOURCE_DIR})

include_directories(${PROJECT_INCLUDE})

set(ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR})

# get_subdir and get_intersection is provided by utils.cmake
include(${PROJECT_SOURCE_DIR}/cmake/utils.cmake)

set(TECOAL_OPS_PATH ${CMAKE_CURRENT_SOURCE_DIR}/interface/ops)
fetch_filename_list(${TECOAL_OPS_PATH} TECOAL_ALL_OPS)

if(BUILD_SPECIFIC_OP)
    set_intersection(BUILD_SPECIFIC_OP TECOAL_ALL_OPS TECOAL_OPS)
    if (NOT TECOAL_OPS)
        message(FATAL_ERROR "build ops is not exist!")
    endif()
else()
    set(TECOAL_OPS ${TECOAL_ALL_OPS})
endif()

foreach(ITEM ${TECOAL_OPS})
    message(STATUS "TECOAL_OPS: ${ITEM}")
endforeach()

# create ual library
add_subdirectory(${ROOT_DIR}/ual)

# create tecoal library
add_subdirectory(${ROOT_DIR}/interface)

# enter the test framework
if(BUILD_TEST)
    add_subdirectory(${ROOT_DIR}/samples)
endif()
