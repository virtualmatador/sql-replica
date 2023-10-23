cmake_minimum_required(VERSION 3.18)
project("sql-replica" VERSION 1.1.0)
enable_testing()

set(CMAKE_PROJECT_DESCRIPTION "Generate SQL from Database definition")
set(CMAKE_PROJECT_HOMEPAGE_URL "https://www.shaidin.com/sql-sync")

set(CPACK_PACKAGE_VENDOR "virtualmatador")
set(CPACK_PACKAGE_FILE_NAME "${CMAKE_PROJECT_NAME}")
set(CPACK_GENERATOR "DEB")
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_VENDOR}")
set(CPACK_DEBIAN_PACKAGE_DEPENDS "")
include(CPack)

add_custom_target("version" ALL
    COMMAND "${CMAKE_COMMAND}" -E echo ${CMAKE_PROJECT_VERSION} >
        "${CMAKE_CURRENT_BINARY_DIR}/version.txt"
)

add_subdirectory("extern/jsonio")
add_subdirectory("extern/cli")
add_subdirectory("extern/sqlr")

add_executable("${CMAKE_PROJECT_NAME}" "main.cpp")
target_link_libraries("${CMAKE_PROJECT_NAME}" "jsonio" "cli" "sqlr")
target_compile_definitions("${CMAKE_PROJECT_NAME}" PRIVATE
    VERSION="${CMAKE_PROJECT_VERSION}"
)
install(TARGETS "${CMAKE_PROJECT_NAME}" DESTINATION "bin")
