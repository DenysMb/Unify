// SPDX-FileCopyrightText: 2025 Denys Madureira
// SPDX-License-Identifier: GPL-3.0-or-later

#include "notificationpresenter.h"
#include <KNotification>
#include <QDebug>
#include <QImage>
#include <QPixmap>
#include <QWebEngineNotification>

NotificationPresenter::NotificationPresenter(QObject *parent)
    : QObject(parent)
{
}

void NotificationPresenter::presentFromQmlWithNotification(QWebEngineNotification *webNotification, const QString &serviceId)
{
    if (!webNotification) {
        qDebug() << "❌ presentFromQmlWithNotification called with null notification";
        return;
    }

    QString title = webNotification->title().isEmpty() ? QStringLiteral("Web Notification") : webNotification->title();
    QString message = webNotification->message();
    QImage icon = webNotification->icon();

    qDebug() << "📢 QML-present notification (with icon):";
    qDebug() << "   Title:" << title;
    qDebug() << "   Message:" << message;
    qDebug() << "   Origin:" << webNotification->origin().host();
    qDebug() << "   Service ID:" << serviceId;
    qDebug() << "   Has icon:" << !icon.isNull() << (icon.isNull() ? QStringLiteral("") : QStringLiteral("(%1x%2)").arg(icon.width()).arg(icon.height()));

    auto *notification = new KNotification(QStringLiteral("notification"), KNotification::CloseOnTimeout, this);
    notification->setComponentName(QStringLiteral("unify"));
    notification->setTitle(title);
    notification->setText(message);

    // Use the icon from the web notification if available, otherwise use default icon
    if (!icon.isNull()) {
        notification->setPixmap(QPixmap::fromImage(icon));
    } else {
        notification->setIconName(QStringLiteral("dialog-information"));
    }

    // Add a default action that will be triggered when the notification is clicked
    KNotificationAction *defaultAction = notification->addDefaultAction(QStringLiteral("Open"));

    // Connect the action's activated signal to emit our notificationClicked signal
    connect(defaultAction, &KNotificationAction::activated, this, [this, serviceId]() {
        qDebug() << "📢 Notification clicked for service:" << serviceId;
        if (!serviceId.isEmpty()) {
            Q_EMIT notificationClicked(serviceId);
        }
    });

    notification->sendEvent();

    // Close the web notification
    webNotification->close();
}

void NotificationPresenter::presentFromQml(const QString &titleIn, const QString &messageIn, const QUrl &originUrl, const QString &serviceId)
{
    QString title = titleIn.isEmpty() ? QStringLiteral("Web Notification") : titleIn;
    QString message = messageIn;

    qDebug() << "📢 QML-present notification (fallback):";
    qDebug() << "   Title:" << title;
    qDebug() << "   Message:" << message;
    qDebug() << "   Origin:" << originUrl.host();
    qDebug() << "   Service ID:" << serviceId;

    auto *notification = new KNotification(QStringLiteral("notification"), KNotification::CloseOnTimeout, this);
    notification->setComponentName(QStringLiteral("unify"));
    notification->setTitle(title);
    notification->setText(message);
    notification->setIconName(QStringLiteral("dialog-information"));

    // Add a default action that will be triggered when the notification is clicked
    KNotificationAction *defaultAction = notification->addDefaultAction(QStringLiteral("Open"));

    // Connect the action's activated signal to emit our notificationClicked signal
    connect(defaultAction, &KNotificationAction::activated, this, [this, serviceId]() {
        qDebug() << "📢 Notification clicked for service:" << serviceId;
        if (!serviceId.isEmpty()) {
            Q_EMIT notificationClicked(serviceId);
        }
    });

    notification->sendEvent();
}

void NotificationPresenter::present(std::unique_ptr<QWebEngineNotification> notification, const QString &serviceId)
{
    if (!notification) {
        qDebug() << "❌ Notification presenter called with null notification";
        return;
    }

    QString title = notification->title().isEmpty() ? QStringLiteral("Web Notification") : notification->title();
    QString message = notification->message();

    qDebug() << "📢 Notification presenter called:";
    qDebug() << "   Title:" << title;
    qDebug() << "   Message:" << message;
    qDebug() << "   Origin:" << notification->origin().host();
    qDebug() << "   Service ID:" << serviceId;

    auto *knotification = new KNotification(QStringLiteral("notification"), KNotification::CloseOnTimeout, this);
    knotification->setComponentName(QStringLiteral("unify"));
    knotification->setTitle(title);
    knotification->setText(message);
    knotification->setIconName(QStringLiteral("dialog-information"));

    // Add a default action that will be triggered when the notification is clicked
    KNotificationAction *defaultAction = knotification->addDefaultAction(QStringLiteral("Open"));

    // Connect the action's activated signal to emit our notificationClicked signal
    connect(defaultAction, &KNotificationAction::activated, this, [this, serviceId]() {
        qDebug() << "📢 Notification clicked for service:" << serviceId;
        if (!serviceId.isEmpty()) {
            Q_EMIT notificationClicked(serviceId);
        }
    });

    knotification->sendEvent();

    notification->close();
}