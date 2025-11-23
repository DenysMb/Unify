// SPDX-FileCopyrightText: 2025 Denys Madureira
// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TRAYICONMANAGER_H
#define TRAYICONMANAGER_H

#include <QAction>
#include <QMenu>
#include <QObject>
#include <QPalette>
#include <QSystemTrayIcon>
#include <QWindow>
#include <QtCore/QObject>

class TrayIconManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool windowVisible READ windowVisible WRITE setWindowVisible NOTIFY windowVisibleChanged)
    Q_PROPERTY(bool hasNotifications READ hasNotifications WRITE setHasNotifications NOTIFY hasNotificationsChanged)

public:
    explicit TrayIconManager(QObject *parent = nullptr);
    ~TrayIconManager() override;

    bool windowVisible() const;
    void setWindowVisible(bool visible);

    bool hasNotifications() const;
    void setHasNotifications(bool hasNotifications);

    Q_INVOKABLE void setMainWindow(QWindow *window);
    Q_INVOKABLE void show();
    Q_INVOKABLE void hide();
    Q_INVOKABLE void showNotification(const QString &title, const QString &message);

Q_SIGNALS:
    void windowVisibleChanged();
    void hasNotificationsChanged();
    void showWindowRequested();
    void hideWindowRequested();
    void quitRequested();

private Q_SLOTS:
    void onActivated(QSystemTrayIcon::ActivationReason reason);
    void updateMenuActions();
    void updateTrayIconForColorScheme();

private:
    void createTrayIcon();
    void createMenu();
    bool isDarkColorScheme() const;
    void updateIconBasedOnColorScheme();
    bool eventFilter(QObject *watched, QEvent *event) override;

    QSystemTrayIcon *m_trayIcon;
    QMenu *m_trayMenu;
    QAction *m_showAction;
    QAction *m_hideAction;
    QAction *m_quitAction;
    QWindow *m_mainWindow;
    bool m_windowVisible;
    bool m_hasNotifications;
};

#endif // TRAYICONMANAGER_H