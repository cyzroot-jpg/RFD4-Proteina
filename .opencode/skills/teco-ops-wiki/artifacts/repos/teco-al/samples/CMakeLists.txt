cmake_minimum_required(VERSION 3.10.2)

set(CMAKE_CXX_LINK_FLAGS "-L$ENV{SDAA_HOME}/lib64  -lsdaart ")
unset(CMAKE_CXX_FLAGS)

foreach(SPECIFIC_OP ${TECOAL_OPS})
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${SPECIFIC_OP}")
        add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/${SPECIFIC_OP})
    endif()
endforeach()