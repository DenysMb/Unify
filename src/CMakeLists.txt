# SPDX-FileCopyrightText: 2025 Denys Madureira
# SPDX-License-Identifier: GPL-3.0-or-later

add_executable(unify)

ecm_add_qml_module(unify
    URI
    io.github.denysmb.unify
)

target_sources(unify
    PRIVATE
    main.cpp
)

ecm_target_qml_sources(unify
    SOURCES
    qml/Main.qml
)

target_link_libraries(unify
    PRIVATE
    Qt6::Quick
    Qt6::Qml
    Qt6::Gui
    Qt6::QuickControls2
    Qt6::Widgets
    Qt6::WebEngineQuick
    Qt6::DBus
    KF6::I18n
    KF6::CoreAddons
    KF6::IconThemes
    KF6::Notifications
)

install(TARGETS unify ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
