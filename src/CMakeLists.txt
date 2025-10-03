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
    configmanager.cpp
    configmanager.h
    oauthmanager.cpp
    oauthmanager.h
)

ecm_target_qml_sources(unify
    SOURCES
    qml/Main.qml
    qml/components/ServiceIconButton.qml
    qml/components/ServicesSidebar.qml
    qml/components/EmptyState.qml
    qml/components/ServiceWebView.qml
    qml/components/DetachedServiceWindow.qml
    qml/components/PopupWindow.qml
    qml/components/WebViewStack.qml
    qml/dialogs/ServiceDialog.qml
    qml/dialogs/PermissionDialog.qml
    qml/dialogs/WorkspaceDialog.qml
    qml/dialogs/OAuth2Dialog.qml
    qml/drawers/WorkspaceDrawer.qml
    qml/utils/Services.js
)

target_link_libraries(unify
    PRIVATE
    Qt6::Quick
    Qt6::Qml
    Qt6::Gui
    Qt6::QuickControls2
    Qt6::Widgets
    Qt6::WebEngineQuick
    Qt6::NetworkAuth
    Qt6::DBus
    KF6::I18n
    KF6::CoreAddons
    KF6::IconThemes
    KF6::Notifications
)

install(TARGETS unify ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
