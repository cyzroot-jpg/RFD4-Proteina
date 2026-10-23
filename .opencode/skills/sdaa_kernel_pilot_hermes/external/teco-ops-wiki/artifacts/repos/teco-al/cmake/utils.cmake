# Use "IN_LIST" operator
cmake_policy(SET CMP0057 NEW)

# get all operations in specific directory such as dnn/blas/rand
macro(get_subdir DIR RET)
    execute_process(
        COMMAND ls -F ${DIR}
        COMMAND grep "/$"
        COMMAND tr "/" " "
        COMMAND tr "\n" " "
        COMMAND xargs
        OUTPUT_VARIABLE _SUBDIRS
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    separate_arguments(_SUBDIRS)
    # foreach(ITEM ${_SUBDIRS})
    #     message(VERBOSE "sub directorys in ${DIR}: ${ITEM}")
    # endforeach()
    set(${RET} ${_SUBDIRS})
endmacro()

# A ∩ B = {x in A AND x in B}
macro(set_intersection A B RET)
    foreach(ITEM ${${A}})
        if (ITEM IN_LIST ${B})
            set(${RET} ${ITEM} ${${RET}})
        endif()
    endforeach()
endmacro()

function(fetch_filename_list dirpath output_list)
    file(GLOB ALL_ITEMS ${dirpath}/*.cpp)
    set(TMP_LIST "")
    
    foreach(ITEM ${ALL_ITEMS})
        get_filename_component(FILE_NAME ${ITEM} NAME)
        string(REGEX REPLACE "\\.cpp$" "" NEW_FILE_NAME "${FILE_NAME}")
        list(APPEND TMP_LIST ${NEW_FILE_NAME})
    endforeach()
 
    set(${output_list} "${TMP_LIST}" PARENT_SCOPE)
endfunction()