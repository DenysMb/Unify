// SPDX-FileCopyrightText: 2025 Denys Madureira
// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef NOTIFICATIONPRESENTER_H
#define NOTIFICATIONPRESENTER_H

#include <QObject>
#include <QString>
#include <QUrl>
#include <memory>

class QWebEngineNotification;

class NotificationPresenter : public QObject
{
    Q_OBJECT

public:
    explicit NotificationPresenter(QObject *parent = nullptr);

    // Present notification from QML with QWebEngineNotification object (includes icon)
    Q_INVOKABLE void presentFromQmlWithNotification(QWebEngineNotification *webNotification, const QString &serviceId);

    // Fallback method without icon (for compatibility)
    Q_INVOKABLE void presentFromQml(const QString &titleIn, const QString &messageIn, const QUrl &originUrl, const QString &serviceId);

    void present(std::unique_ptr<QWebEngineNotification> notification, const QString &serviceId = QString());

Q_SIGNALS:
    void notificationClicked(const QString &serviceId);
};

#endif // NOTIFICATIONPRESENTER_H