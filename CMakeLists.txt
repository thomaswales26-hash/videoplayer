cmake_minimum_required(VERSION 3.24)
project(UniversalVideoPlayer NONE)

add_custom_target(UniversalVideoPlayer ALL
    COMMAND "${CMAKE_SOURCE_DIR}/build.sh"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    USES_TERMINAL
)
