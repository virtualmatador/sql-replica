cmake_minimum_required(VERSION 3.13)
file(GLOB sources "*.cpp")
foreach(source ${sources})
    get_filename_component(base "${source}" NAME_WE)
    if(base STREQUAL "mysql")
        continue()
    endif()
    add_executable("sqlr-${base}" "${source}")
    set_property(TARGET "sqlr-${base}" PROPERTY CXX_STANDARD 17)
    target_link_libraries("sqlr-${base}" "sqlr")
    target_compile_definitions("sqlr-${base}" PRIVATE
        SQLR_TEST_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
    )
    add_test("sqlr-${base}" "sqlr-${base}")
endforeach()

add_executable("sqlr-mysql" "mysql.cpp")
set_property(TARGET "sqlr-mysql" PROPERTY CXX_STANDARD 17)
target_link_libraries("sqlr-mysql" "sqlr")
target_compile_definitions("sqlr-mysql" PRIVATE
    SQLR_TEST_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
)

file(GLOB mysql_fixtures LIST_DIRECTORIES true "${CMAKE_CURRENT_SOURCE_DIR}/mysql/*")
foreach(fixture ${mysql_fixtures})
    if(IS_DIRECTORY "${fixture}" AND EXISTS "${fixture}/1.json")
        get_filename_component(name "${fixture}" NAME)
        add_test("sqlr-mysql-${name}" "sqlr-mysql" "${fixture}")
        set_tests_properties("sqlr-mysql-${name}" PROPERTIES TIMEOUT 180)
    endif()
endforeach()
