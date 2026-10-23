cmake_minimum_required(VERSION 3.10.2)

# project(tecoal)
set(TECOAL_DIR ${CMAKE_CURRENT_SOURCE_DIR})

# integrate dnn common files
file(GLOB_RECURSE SRC_TECOAL_COMMON "${TECOAL_DIR}/common/*.cpp")

foreach(ITEM ${SRC_TECOAL_COMMON})
    message(VERBOSE "rand common file is ${ITEM}")
endforeach()

# integrate dnn src files
set(SRC_TECOAL_API)

foreach(SPECIFIC_OP ${TECOAL_OPS})
    file(GLOB_RECURSE SRC_API_ITER "${TECOAL_DIR}/ops/${SPECIFIC_OP}.cpp")
    list(APPEND SRC_TECOAL_API ${SRC_API_ITER})
endforeach()

foreach(ITEM ${SRC_TECOAL_API})
    message(VERBOSE "rand api file is ${ITEM}")
endforeach()

# integrate dnn all files
list(APPEND SRC_TECOAL ${SRC_TECOAL_COMMON} ${SRC_TECOAL_API} ${SRC_UAL})

set(complie_options -O3 -msimd -fPIC -flto -x sdaa -std=c++11)

add_library(tecoal_objs OBJECT ${SRC_TECOAL})
set_source_files_properties(${SRC_TECOAL} PROPERTIES LANGUAGE CXX)
set_target_properties(tecoal_objs PROPERTIES LINKER_LANGUAGE CXX)
target_include_directories(tecoal_objs PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_compile_options(tecoal_objs PRIVATE ${complie_options})

add_custom_target(tecoal ALL
    COMMAND mkdir -p ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}
    COMMAND tecocc $<TARGET_OBJECTS:tecoal_objs> ${RT_OBJS} ${KERNEL_OBJS} -flto -ffp-contract=fast -fPIC -shared --sdaa-link -fuse-ld=lld
    -o ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libtecoal.so
    COMMAND_EXPAND_LISTS
)
add_dependencies(tecoal tecoal_objs)

