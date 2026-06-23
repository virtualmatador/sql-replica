cmake_minimum_required(VERSION 3.13)
add_library("sqlr" STATIC
    "schema.cpp"
    "objects.cpp"
    "tables.cpp"
    "routines.cpp"
    "users.cpp"
)
set_property(TARGET "sqlr" PROPERTY CXX_STANDARD 20)
target_include_directories("sqlr" INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries("sqlr" PUBLIC "jsonio")
