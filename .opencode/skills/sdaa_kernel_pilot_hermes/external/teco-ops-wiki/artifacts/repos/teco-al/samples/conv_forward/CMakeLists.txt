cmake_minimum_required(VERSION 3.10.2)

add_executable(test_conv_forward test_conv_forward.cpp)
add_dependencies(test_conv_forward tecoal)
target_include_directories(test_conv_forward PUBLIC ${PROJECT_SOURCE_DIR}/interface/include)
target_link_libraries(test_conv_forward PRIVATE -L${CMAKE_LIBRARY_OUTPUT_DIRECTORY} -ltecoal -fuse-ld=lld -Wl,-rpath=${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
