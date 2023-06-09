# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.20.0)

macro(app_set_runner_args)
  board_runner_args(dfu-util "--dfuse-modifiers=force:mass-erase")
  board_runner_args(pyocd "--erase")
  board_runner_args(nrfjprog "--erase")
endmacro()

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(ld2410_test)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Werror -Wall -Wextra")

target_include_directories(app PRIVATE
    src/system
    src/util
)

target_sources(app PRIVATE
  src/main.c
  src/system/battery_sys.c
)