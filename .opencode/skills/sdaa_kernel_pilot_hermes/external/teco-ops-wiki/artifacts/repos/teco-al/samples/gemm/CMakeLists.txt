cmake_minimum_required(VERSION 3.10.2)

add_executable(test_hgemm test_hgemm.cpp)
add_dependencies(test_hgemm tecoal)
target_include_directories(test_hgemm PUBLIC ${PROJECT_SOURCE_DIR}/interface/include)
target_link_libraries(test_hgemm PRIVATE -L${CMAKE_LIBRARY_OUTPUT_DIRECTORY} -ltecoal -fuse-ld=lld -Wl,-rpath=${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
