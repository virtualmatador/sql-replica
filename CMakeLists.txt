cmake_minimum_required(VERSION 3.18)
project("sql-replica" VERSION 2.0.0)
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
    COMMAND "${CMAKE_COMMAND}" -E echo ${CMAKE_PROJECT_VERSION} > version.txt
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
)

add_custom_target("readme" ALL VERBATIM
    COMMAND csplit -z ${CMAKE_CURRENT_SOURCE_DIR}/README.md
        -f input "%^# Input$%" "/^#{1,2} .*$/"
    COMMAND pandoc -f markdown input00 -o input00.html
    COMMAND csplit -z ${CMAKE_CURRENT_SOURCE_DIR}/README.md
        -f table "%^### Table$%" "/^#{1,3} .*$/"
    COMMAND pandoc -f markdown table00 -o table00.html
    COMMAND csplit -z ${CMAKE_CURRENT_SOURCE_DIR}/README.md
        -f view "%^### View$%" "/^#{1,3} .*$/"
    COMMAND pandoc -f markdown view00 -o view00.html
    COMMAND csplit -z ${CMAKE_CURRENT_SOURCE_DIR}/README.md
        -f routine "%^### Routine$%" "/^#{1,3} .*$/"
    COMMAND pandoc -f markdown routine00 -o routine00.html
    COMMAND csplit -z ${CMAKE_CURRENT_SOURCE_DIR}/README.md
        -f user "%^### User$%" "/^#{1,3} .*$/"
    COMMAND pandoc -f markdown user00 -o user00.html
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
)

add_custom_target("sql-sync-examples" ALL VERBATIM
    COMMAND "${CMAKE_COMMAND}" -E copy
        "${CMAKE_CURRENT_SOURCE_DIR}/test/sql-sync/schema.json"
        "${CMAKE_CURRENT_SOURCE_DIR}/test/sql-sync/tables.json"
        "${CMAKE_CURRENT_SOURCE_DIR}/test/sql-sync/views.json"
        "${CMAKE_CURRENT_SOURCE_DIR}/test/sql-sync/routines.json"
        "${CMAKE_CURRENT_SOURCE_DIR}/test/sql-sync/users.json"
        "${CMAKE_CURRENT_SOURCE_DIR}/test/sql-sync/sql.sql"
        "${CMAKE_CURRENT_BINARY_DIR}"
)

add_subdirectory("extern/jsonio")
add_subdirectory("extern/cli")
add_subdirectory("src")
add_subdirectory("test")

add_executable("${CMAKE_PROJECT_NAME}" "main.cpp")
target_link_libraries("${CMAKE_PROJECT_NAME}" "jsonio" "cli" "sqlr")
target_compile_definitions("${CMAKE_PROJECT_NAME}" PRIVATE
    VERSION="${CMAKE_PROJECT_VERSION}"
)
install(TARGETS "${CMAKE_PROJECT_NAME}" DESTINATION "bin")
