
cmake_minimum_required( VERSION 2.6.3 )

SET(CMAKE_SYSTEM_NAME Linux)
SET(CMAKE_SYSTEM_PROCESSOR "armv7-a_hardfp")

add_definitions(-fPIC)
add_definitions(-DARMLINUX)
add_definitions(-D__gnu_linux__)
