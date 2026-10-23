cmake_minimum_required(VERSION 3.10.2)

# project(ual)

set(UAL_DIR ${CMAKE_CURRENT_SOURCE_DIR})

file(GLOB_RECURSE SRC_UAL_COMMON "${UAL_DIR}/com/*.cpp")
foreach(SPECIFIC_OP ${TECOAL_OPS})
    file(GLOB_RECURSE SRC_OPS_ITER "${UAL_DIR}/ops/${SPECIFIC_OP}/*.cpp")
    list(APPEND SRC_UAL_OPS ${SRC_OPS_ITER})
    file(GLOB_RECURSE SRC_SLAVE_ITER "${UAL_DIR}/kernel/${SPECIFIC_OP}/*.scpp")
    list(APPEND SRC_UAL_KERNEL ${SRC_SLAVE_ITER})
    set_source_files_properties(${SRC_UAL_KERNEL} PROPERTIES LANGUAGE CXX)
endforeach()

foreach(ITEM ${SRC_UAL_COMMON})
    message(VERBOSE "ual common file is ${ITEM}")
endforeach()

foreach(ITEM ${SRC_UAL_OPS})
    message(VERBOSE "ual ops file is ${ITEM}")
endforeach()

foreach(ITEM ${SRC_UAL_KERNEL})
    message(VERBOSE "ual kernel file is ${ITEM}")
endforeach()

list(APPEND SRC_UAL 
    ${SRC_UAL_COMMON} 
    ${SRC_UAL_OPS} 
    ${SRC_UAL_KERNEL})

set(SRC_UAL ${SRC_UAL} PARENT_SCOPE)
