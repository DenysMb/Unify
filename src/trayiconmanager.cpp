// SPDX-FileCopyrightText: 2025 Denys Madureira
// SPDX-License-Identifier: GPL-3.0-or-later

#include "trayiconmanager.h"
#include <KLocalizedString>
#include <QDebug>
#include <QEvent>
#include <QGuiApplication>
#include <QIcon>
#include <QPalette>

TrayIconManager::TrayIconManager(QObject *parent)
    : QObject(parent)
    , m_trayIcon(nullptr)
    , m_trayMenu(nullptr)
    , m_showAction(nullptr)
    , m_hideAction(nullptr)
    , m_quitAction(nullptr)
    , m_mainWindow(nullptr)
    , m_windowVisible(true)
    , m_hasNotifications(false)
{
    createTrayIcon();
    createMenu();

    // Install event filter to detect palette changes
    qApp->installEventFilter(this);

    // Set initial icon based on current color scheme
    updateIconBasedOnColorScheme();
}

TrayIconManager::~TrayIconManager()
{
    qApp->removeEventFilter(this);
    if (m_trayIcon) {
        m_trayIcon->hide();
        delete m_trayIcon;
    }
}

void TrayIconManager::createTrayIcon()
{
    m_trayIcon = new QSystemTrayIcon(this);
    m_trayIcon->setToolTip(i18n("Unify"));

    connect(m_trayIcon, &QSystemTrayIcon::activated, this, &TrayIconManager::onActivated);

    // Icon will be set by updateIconBasedOnColorScheme()
}

void TrayIconManager::createMenu()
{
    m_trayMenu = new QMenu();

    // Create "Show Unify" action
    m_showAction = new QAction(i18n("Show Unify"), this);
    m_showAction->setIcon(QIcon::fromTheme(QStringLiteral("window")));
    connect(m_showAction, &QAction::triggered, this, &TrayIconManager::showWindowRequested);
    m_trayMenu->addAction(m_showAction);

    // Create "Hide Unify" action
    m_hideAction = new QAction(i18n("Hide Unify"), this);
    m_hideAction->setIcon(QIcon::fromTheme(QStringLiteral("window-minimize")));
    connect(m_hideAction, &QAction::triggered, this, &TrayIconManager::hideWindowRequested);
    m_trayMenu->addAction(m_hideAction);

    m_trayMenu->addSeparator();

    // Create "Quit Unify" action (always visible)
    m_quitAction = new QAction(i18n("Quit Unify"), this);
    m_quitAction->setIcon(QIcon::fromTheme(QStringLiteral("application-exit")));
    connect(m_quitAction, &QAction::triggered, this, &TrayIconManager::quitRequested);
    m_trayMenu->addAction(m_quitAction);

    m_trayIcon->setContextMenu(m_trayMenu);

    // Update menu to show correct actions
    updateMenuActions();
}

void TrayIconManager::onActivated(QSystemTrayIcon::ActivationReason reason)
{
    if (reason == QSystemTrayIcon::Trigger || reason == QSystemTrayIcon::DoubleClick) {
        // Toggle window visibility on click/double-click
        if (m_windowVisible) {
            Q_EMIT hideWindowRequested();
        } else {
            Q_EMIT showWindowRequested();
        }
    }
}

void TrayIconManager::updateMenuActions()
{
    // Show "Hide Unify" only when window is visible
    m_hideAction->setVisible(m_windowVisible);

    // Show "Show Unify" only when window is hidden
    m_showAction->setVisible(!m_windowVisible);
}

bool TrayIconManager::windowVisible() const
{
    return m_windowVisible;
}

void TrayIconManager::setWindowVisible(bool visible)
{
    if (m_windowVisible != visible) {
        m_windowVisible = visible;
        updateMenuActions();
        Q_EMIT windowVisibleChanged();
    }
}

bool TrayIconManager::hasNotifications() const
{
    return m_hasNotifications;
}

void TrayIconManager::setHasNotifications(bool hasNotifications)
{
    if (m_hasNotifications != hasNotifications) {
        m_hasNotifications = hasNotifications;
        qDebug() << "🔔 Notification state changed:" << (hasNotifications ? "HAS notifications" : "NO notifications");
        updateIconBasedOnColorScheme();
        Q_EMIT hasNotificationsChanged();
    }
}

void TrayIconManager::setMainWindow(QWindow *window)
{
    m_mainWindow = window;
    if (m_mainWindow) {
        // Sync initial visibility state
        setWindowVisible(m_mainWindow->isVisible());
    }
}

void TrayIconManager::show()
{
    if (m_trayIcon) {
        m_trayIcon->show();
        qDebug() << "System tray icon shown";
    }
}

void TrayIconManager::hide()
{
    if (m_trayIcon) {
        m_trayIcon->hide();
        qDebug() << "System tray icon hidden";
    }
}

void TrayIconManager::showNotification(const QString &title, const QString &message)
{
    if (m_trayIcon && m_trayIcon->isVisible()) {
        m_trayIcon->showMessage(title, message, QSystemTrayIcon::Information, 5000);
        qDebug() << "📢 Tray notification shown:" << title;
    }
}

bool TrayIconManager::isDarkColorScheme() const
{
    // Get the current application palette
    QPalette palette = qApp->palette();

    // Check if the window background is dark
    // A color is considered dark if its lightness is less than 128 (middle of 0-255 range)
    QColor backgroundColor = palette.color(QPalette::Window);
    int lightness = backgroundColor.lightness();

    qDebug() << "🎨 Color scheme detection - Background lightness:" << lightness;

    return lightness < 128;
}

void TrayIconManager::updateIconBasedOnColorScheme()
{
    if (!m_trayIcon) {
        return;
    }

    QString iconPath;

    if (m_hasNotifications) {
        // Use single notification icon regardless of color scheme
        iconPath = QStringLiteral(":/io.github.denysmb.unify/assets/unify-tray-notification.png");
        qDebug() << "🔔 Tray icon updated: using NOTIFICATION icon";
    } else {
        // Use color scheme appropriate icon when no notifications
        bool isDark = isDarkColorScheme();
        iconPath = isDark ? QStringLiteral(":/io.github.denysmb.unify/assets/unify-tray-light.png")
                          : QStringLiteral(":/io.github.denysmb.unify/assets/unify-tray-dark.png");
        qDebug() << "🎨 Tray icon updated for" << (isDark ? "DARK" : "LIGHT") << "color scheme, using" << (isDark ? "LIGHT" : "DARK") << "normal icon";
    }

    QIcon trayIcon(iconPath);
    m_trayIcon->setIcon(trayIcon);
}

void TrayIconManager::updateTrayIconForColorScheme()
{
    updateIconBasedOnColorScheme();
}

bool TrayIconManager::eventFilter(QObject *watched, QEvent *event)
{
    // Detect when the application palette changes (theme/color scheme change)
    if (event->type() == QEvent::ApplicationPaletteChange || event->type() == QEvent::PaletteChange) {
        qDebug() << "🎨 Palette change detected, updating tray icon...";
        updateIconBasedOnColorScheme();
    }

    return QObject::eventFilter(watched, event);
}