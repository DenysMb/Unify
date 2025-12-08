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
    core/configmanager.cpp
    core/configmanager.h
    core/notificationpresenter.cpp
    core/notificationpresenter.h
    core/applicationshortcutmanager.cpp
    core/applicationshortcutmanager.h
    ui/trayiconmanager.cpp
    ui/trayiconmanager.h
    utils/faviconcache.cpp
    utils/faviconcache.h
    utils/keyeventfilter.cpp
    utils/keyeventfilter.h
    resources.qrc
)

ecm_target_qml_sources(unify
    SOURCES
    qml/Main.qml
    qml/components/ServiceIconButton.qml
    qml/components/ServicesSidebar.qml
    qml/components/ShortcutIconButton.qml
    qml/components/EmptyState.qml
    qml/components/ServiceWebView.qml
    qml/components/DetachedServiceWindow.qml
    qml/components/PopupWindow.qml
    qml/components/WebViewStack.qml
    qml/components/InternalLinkOverlay.qml
    qml/components/WorkspacesBar.qml
    qml/dialogs/ServiceDialog.qml
    qml/dialogs/PermissionDialog.qml
    qml/dialogs/WorkspaceDialog.qml
    qml/dialogs/ApplicationShortcutDialog.qml
    qml/drawers/WorkspaceDrawer.qml
    qml/utils/Services.js
    qml/utils/AntiDetection.js
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
    Qt6::Network
    KF6::I18n
    KF6::CoreAddons
    KF6::IconThemes
    KF6::Notifications
    KF6::Service
    KF6::KIOGui
)

install(TARGETS unify ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
