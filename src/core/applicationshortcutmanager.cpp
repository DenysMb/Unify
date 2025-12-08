#include "applicationshortcutmanager.h"

#include <KApplicationTrader>
#include <KIO/ApplicationLauncherJob>
#include <KService>
#include <QDebug>

#include <algorithm>

ApplicationShortcutManager::ApplicationShortcutManager(QObject *parent)
    : QObject(parent)
{
    loadApplications();
}

QVariantList ApplicationShortcutManager::installedApplications() const
{
    return m_applications;
}

void ApplicationShortcutManager::loadApplications()
{
    m_applications.clear();

    const KService::List services = KApplicationTrader::query([](const KService::Ptr &service) {
        return service->isApplication() && !service->noDisplay();
    });

    for (const KService::Ptr &service : services) {
        QVariantMap map;
        map[QStringLiteral("desktopFileName")] = service->desktopEntryName();
        map[QStringLiteral("name")] = service->name();
        map[QStringLiteral("genericName")] = service->genericName();
        map[QStringLiteral("comment")] = service->comment();
        map[QStringLiteral("icon")] = service->icon();
        map[QStringLiteral("exec")] = service->exec();
        map[QStringLiteral("categories")] = service->categories();
        m_applications.append(map);
    }

    std::sort(m_applications.begin(), m_applications.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap()[QStringLiteral("name")].toString().toLower() < b.toMap()[QStringLiteral("name")].toString().toLower();
    });

    Q_EMIT installedApplicationsChanged();
    qDebug() << "Loaded" << m_applications.size() << "installed applications";
}

bool ApplicationShortcutManager::launchApplication(const QString &desktopFileName)
{
    KService::Ptr service = KService::serviceByDesktopName(desktopFileName);
    if (!service) {
        const QString error = tr("Application not found: %1").arg(desktopFileName);
        qWarning() << error;
        Q_EMIT launchError(error);
        return false;
    }

    auto *job = new KIO::ApplicationLauncherJob(service);
    connect(job, &KJob::result, this, [this, desktopFileName](KJob *job) {
        if (job->error()) {
            Q_EMIT launchError(job->errorString());
        } else {
            Q_EMIT applicationLaunched(desktopFileName);
        }
    });
    job->start();
    return true;
}

QVariantMap ApplicationShortcutManager::getApplicationInfo(const QString &desktopFileName) const
{
    for (const QVariant &app : m_applications) {
        QVariantMap appMap = app.toMap();
        if (appMap[QStringLiteral("desktopFileName")].toString() == desktopFileName) {
            return appMap;
        }
    }
    return QVariantMap();
}

QVariantList ApplicationShortcutManager::searchApplications(const QString &query) const
{
    if (query.isEmpty()) {
        return m_applications;
    }

    QVariantList results;
    const QString lowerQuery = query.toLower();

    for (const QVariant &app : m_applications) {
        QVariantMap appMap = app.toMap();
        const QString name = appMap[QStringLiteral("name")].toString().toLower();
        const QString genericName = appMap[QStringLiteral("genericName")].toString().toLower();
        const QString comment = appMap[QStringLiteral("comment")].toString().toLower();

        if (name.contains(lowerQuery) || genericName.contains(lowerQuery) || comment.contains(lowerQuery)) {
            results.append(app);
        }
    }
    return results;
}

void ApplicationShortcutManager::refreshApplications()
{
    loadApplications();
}
