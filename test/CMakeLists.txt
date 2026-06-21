cmake_minimum_required(VERSION 3.13)
file(GLOB sources "*.cpp")
foreach(source ${sources})
    get_filename_component(base "${source}" NAME_WE)
    add_executable("sqlr-${base}" "${source}")
    set_property(TARGET "sqlr-${base}" PROPERTY CXX_STANDARD 17)
    target_link_libraries("sqlr-${base}" "sqlr")
    target_compile_definitions("sqlr-${base}" PRIVATE
        SQLR_TEST_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
    )
    add_test("sqlr-${base}" "sqlr-${base}")
endforeach()
