# SPDX-FileCopyrightText: 2025 Denys Madureira
# SPDX-License-Identifier: GPL-3.0-or-later

cmake_minimum_required(VERSION 3.20)
project(Unify VERSION 0.1.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

set(QT6_MIN_VERSION 6.5.0)
set(KF6_MIN_VERSION 6.0.0)

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${ECM_MODULE_PATH})
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

include(FeatureSummary)
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMSetupVersion)
include(ECMFindQmlModule)
include(KDEGitCommitHooks)
include(KDEClangFormat)

ecm_setup_version(${PROJECT_VERSION} VARIABLE_PREFIX UNIFY VERSION_HEADER
                  "${CMAKE_CURRENT_BINARY_DIR}/src/version-unify.h")

find_package(Qt6 ${QT6_MIN_VERSION} REQUIRED COMPONENTS
    Core
    Quick
    Test
    Gui
    Qml
    QuickControls2
    Widgets
    WebEngineQuick
)

find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    Kirigami
    I18n
    CoreAddons
    QQC2DesktopStyle
    IconThemes
    Notifications
)
find_package(KF6 REQUIRED COMPONENTS KirigamiAddons)

ecm_find_qmlmodule(org.kde.kirigami REQUIRED)
ecm_find_qmlmodule(org.kde.kirigamiaddons.formcard 1.0)
ecm_find_qmlmodule(QtQuick.Effects)
ecm_find_qmlmodule(org.kde.iconthemes 1.0)

qt_policy(SET QTP0001 NEW)
set(QT_QML_GENERATE_QMLLS_INI ON)

qt_policy(SET QTP0001 NEW)
add_subdirectory(src)

# Install metainfo file
install(FILES io.github.denysmb.unify.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})

# Install icon
install(FILES src/assets/unify.svg DESTINATION ${KDE_INSTALL_ICONDIR}/hicolor/scalable/apps RENAME io.github.denysmb.unify.svg)

set(TRANSLATION_TARGET_NAME ${PROJECT_NAME})
add_subdirectory(po)
ki18n_install(po)

# Install desktop file
install_i18n_desktop_file(${CMAKE_SOURCE_DIR}/io.github.denysmb.unify.desktop ${KDE_INSTALL_APPDIR})

# Install notification configuration
install(FILES unify.notifyrc DESTINATION ${KDE_INSTALL_KNOTIFYRCDIR})

file(GLOB_RECURSE ALL_CLANG_FORMAT_SOURCE_FILES src/*.cpp src/*.h)
kde_clang_format(${ALL_CLANG_FORMAT_SOURCE_FILES})
kde_configure_git_pre_commit_hook(CHECKS CLANG_FORMAT)

feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES FATAL_ON_MISSING_REQUIRED_PACKAGES)
