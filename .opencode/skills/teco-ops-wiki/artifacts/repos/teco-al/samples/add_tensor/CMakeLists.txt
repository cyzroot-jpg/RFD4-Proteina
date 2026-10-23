cmake_minimum_required(VERSION 3.10.2)

add_executable(test_add_tensor test_add_tensor.cpp)
add_dependencies(test_add_tensor tecoal)
target_include_directories(test_add_tensor PUBLIC ${PROJECT_SOURCE_DIR}/interface/include)
target_link_libraries(test_add_tensor PRIVATE -L${CMAKE_LIBRARY_OUTPUT_DIRECTORY} -ltecoal -fuse-ld=lld -Wl,-rpath=${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
