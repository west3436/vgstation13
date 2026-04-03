cmake_minimum_required(VERSION 3.15)
project(atmos_native LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(atmos_native SHARED
    src/byondapi_cpp_wrappers.cpp
    src/gas_mixture.cpp
    src/state.cpp
    src/main.cpp
)

target_include_directories(atmos_native PRIVATE include/)

# Link byondapi.lib on Windows
if(WIN32)
    target_link_libraries(atmos_native PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include/byondapi.lib)
endif()

# Optimization flags
if(MSVC)
    target_compile_options(atmos_native PRIVATE /O2 /fp:fast)
else()
    target_compile_options(atmos_native PRIVATE -O3 -ffast-math)
endif()

set_target_properties(atmos_native PROPERTIES
    OUTPUT_NAME "atmos_native"
    PREFIX ""
)
