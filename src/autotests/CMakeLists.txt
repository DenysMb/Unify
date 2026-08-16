# SPDX-FileCopyrightText: 2025 Denys Madureira
# SPDX-License-Identifier: GPL-3.0-or-later

add_executable(tlsproxybridgetest
    tlsproxybridgetest.cpp
    ../core/tlsproxybridge.cpp
    ../core/tlsproxybridge.h
)

target_include_directories(tlsproxybridgetest PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/..)

target_link_libraries(tlsproxybridgetest
    PRIVATE
    Qt6::Test
    Qt6::Network
    Qt6::Core
)

add_test(NAME tlsproxybridgetest COMMAND tlsproxybridgetest)
