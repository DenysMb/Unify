#include "applicationshortcutmanager.h"

#include <KApplicationTrader>
#include <KIO/ApplicationLauncherJob>
#include <KService>
#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QProcess>
#include <QRegularExpression>
#include <QSet>
#include <QSettings>
#include <QStandardPaths>
#include <QTextStream>

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

    loadApplicationsFromKService();

    if (m_applications.isEmpty()) {
        qDebug() << "KService returned no applications, falling back to manual desktop file scanning";
        loadApplicationsFromDesktopFiles();
    }

    std::sort(m_applications.begin(), m_applications.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap()[QStringLiteral("name")].toString().toLower() < b.toMap()[QStringLiteral("name")].toString().toLower();
    });

    Q_EMIT installedApplicationsChanged();
    qDebug() << "Loaded" << m_applications.size() << "installed applications";
}

void ApplicationShortcutManager::loadApplicationsFromKService()
{
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
}

bool ApplicationShortcutManager::isRunningInFlatpak() const
{
    return QFile::exists(QStringLiteral("/.flatpak-info"));
}

void ApplicationShortcutManager::loadApplicationsFromDesktopFiles()
{
    QSet<QString> processedIds;

    if (isRunningInFlatpak()) {
        qDebug() << "Running in Flatpak, using flatpak-spawn to access host applications";
        loadApplicationsViaFlatpakSpawn(processedIds);
    }

    QStringList searchPaths;

    searchPaths << QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation);
    searchPaths << QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation);

    searchPaths << QStringLiteral("/usr/share/applications");
    searchPaths << QStringLiteral("/usr/local/share/applications");
    searchPaths << QDir::homePath() + QStringLiteral("/.local/share/applications");

    searchPaths << QStringLiteral("/var/lib/flatpak/exports/share/applications");
    searchPaths << QDir::homePath() + QStringLiteral("/.local/share/flatpak/exports/share/applications");

    searchPaths << QStringLiteral("/var/lib/snapd/desktop/applications");

    const QString xdgDataDirs = QString::fromLocal8Bit(qgetenv("XDG_DATA_DIRS"));
    if (!xdgDataDirs.isEmpty()) {
        const QStringList dataDirs = xdgDataDirs.split(QLatin1Char(':'), Qt::SkipEmptyParts);
        for (const QString &dir : dataDirs) {
            searchPaths << dir + QStringLiteral("/applications");
        }
    }

    searchPaths.removeDuplicates();

    qDebug() << "Scanning local desktop files in paths:";
    for (const QString &path : searchPaths) {
        QDir dir(path);
        if (dir.exists()) {
            qDebug() << "  " << path << "[EXISTS]";
            scanDesktopFilesInDirectory(path, processedIds);
        }
    }
}

void ApplicationShortcutManager::loadApplicationsViaFlatpakSpawn(QSet<QString> &processedIds)
{
    QStringList hostPaths = {
        QStringLiteral("/usr/share/applications"),
        QStringLiteral("/usr/local/share/applications"),
        QDir::homePath() + QStringLiteral("/.local/share/applications"),
        QStringLiteral("/var/lib/flatpak/exports/share/applications"),
        QDir::homePath() + QStringLiteral("/.local/share/flatpak/exports/share/applications"),
    };

    for (const QString &hostPath : hostPaths) {
        QProcess process;
        process.start(QStringLiteral("flatpak-spawn"),
                      {QStringLiteral("--host"), QStringLiteral("find"), QStringLiteral("-L"), hostPath,
                       QStringLiteral("-maxdepth"), QStringLiteral("2"),
                       QStringLiteral("-name"), QStringLiteral("*.desktop"),
                       QStringLiteral("-type"), QStringLiteral("f")});

        if (!process.waitForFinished(5000)) {
            qDebug() << "  flatpak-spawn timeout for" << hostPath;
            continue;
        }

        if (process.exitCode() != 0) {
            continue;
        }

        const QString output = QString::fromUtf8(process.readAllStandardOutput());
        const QStringList desktopFiles = output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);

        int added = 0;
        for (const QString &desktopFile : desktopFiles) {
            QVariantMap app = parseDesktopFileViaFlatpakSpawn(desktopFile.trimmed());
            if (app.isEmpty()) {
                continue;
            }

            const QString desktopFileName = app[QStringLiteral("desktopFileName")].toString();
            if (processedIds.contains(desktopFileName)) {
                continue;
            }

            processedIds.insert(desktopFileName);
            m_applications.append(app);
            added++;
        }

        if (!desktopFiles.isEmpty()) {
            qDebug() << "  Host path" << hostPath << "- files:" << desktopFiles.size() << ", added:" << added;
        }
    }
}

QVariantMap ApplicationShortcutManager::parseDesktopFileViaFlatpakSpawn(const QString &filePath) const
{
    if (filePath.isEmpty()) {
        return {};
    }

    QProcess process;
    process.start(QStringLiteral("flatpak-spawn"),
                  {QStringLiteral("--host"), QStringLiteral("cat"), filePath});

    if (!process.waitForFinished(3000)) {
        return {};
    }

    if (process.exitCode() != 0) {
        return {};
    }

    const QString content = QString::fromUtf8(process.readAllStandardOutput());
    return parseDesktopFileContent(content, filePath);
}

QVariantMap ApplicationShortcutManager::parseDesktopFileContent(const QString &content, const QString &filePath) const
{
    QVariantMap result;
    bool inDesktopEntry = false;

    QString name;
    QString genericName;
    QString comment;
    QString icon;
    QString exec;
    QStringList categories;
    bool noDisplay = false;
    QString type;
    bool hidden = false;

    const QStringList lines = content.split(QLatin1Char('\n'));
    for (const QString &rawLine : lines) {
        QString line = rawLine.trimmed();

        if (line.isEmpty() || line.startsWith(QLatin1Char('#'))) {
            continue;
        }

        if (line.startsWith(QLatin1Char('[')) && line.endsWith(QLatin1Char(']'))) {
            QString group = line.mid(1, line.length() - 2);
            inDesktopEntry = (group == QStringLiteral("Desktop Entry"));
            continue;
        }

        if (!inDesktopEntry) {
            continue;
        }

        const int equalsPos = line.indexOf(QLatin1Char('='));
        if (equalsPos <= 0) {
            continue;
        }

        const QString key = line.left(equalsPos).trimmed();
        const QString value = line.mid(equalsPos + 1).trimmed();

        if (key == QStringLiteral("Type")) {
            type = value;
        } else if (key == QStringLiteral("Name")) {
            name = value;
        } else if (key == QStringLiteral("GenericName")) {
            genericName = value;
        } else if (key == QStringLiteral("Comment")) {
            comment = value;
        } else if (key == QStringLiteral("Icon")) {
            icon = value;
        } else if (key == QStringLiteral("Exec")) {
            exec = value;
        } else if (key == QStringLiteral("Categories")) {
            categories = value.split(QLatin1Char(';'), Qt::SkipEmptyParts);
        } else if (key == QStringLiteral("NoDisplay")) {
            noDisplay = (value.toLower() == QStringLiteral("true"));
        } else if (key == QStringLiteral("Hidden")) {
            hidden = (value.toLower() == QStringLiteral("true"));
        }
    }

    if (type != QStringLiteral("Application") || noDisplay || hidden || name.isEmpty()) {
        return {};
    }

    QFileInfo fileInfo(filePath);
    QString desktopFileName = fileInfo.completeBaseName();

    result[QStringLiteral("desktopFileName")] = desktopFileName;
    result[QStringLiteral("name")] = name;
    result[QStringLiteral("genericName")] = genericName;
    result[QStringLiteral("comment")] = comment;

    if (isRunningInFlatpak() && !icon.isEmpty() && !icon.startsWith(QLatin1Char('/'))) {
        QString cachedIcon = cacheIconFromHost(icon);
        result[QStringLiteral("icon")] = cachedIcon.isEmpty() ? icon : cachedIcon;
    } else {
        result[QStringLiteral("icon")] = icon;
    }

    result[QStringLiteral("exec")] = exec;
    result[QStringLiteral("categories")] = categories;
    result[QStringLiteral("desktopFilePath")] = filePath;

    return result;
}

QString ApplicationShortcutManager::cacheIconFromHost(const QString &iconName) const
{
    if (iconName.isEmpty()) {
        return {};
    }

    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/icons");
    QDir().mkpath(cacheDir);

    const QStringList cachedExtensions = {QStringLiteral(".svg"), QStringLiteral(".png"), QStringLiteral(".xpm")};
    for (const QString &ext : cachedExtensions) {
        QString cachedPath = cacheDir + QStringLiteral("/") + iconName + ext;
        if (QFile::exists(cachedPath)) {
            return cachedPath;
        }
    }

    const QStringList possiblePaths = {
        QStringLiteral("/usr/share/icons/hicolor/scalable/apps/") + iconName + QStringLiteral(".svg"),
        QStringLiteral("/usr/share/icons/hicolor/256x256/apps/") + iconName + QStringLiteral(".png"),
        QStringLiteral("/usr/share/icons/hicolor/128x128/apps/") + iconName + QStringLiteral(".png"),
        QStringLiteral("/usr/share/icons/hicolor/48x48/apps/") + iconName + QStringLiteral(".png"),
        QStringLiteral("/usr/share/pixmaps/") + iconName + QStringLiteral(".svg"),
        QStringLiteral("/usr/share/pixmaps/") + iconName + QStringLiteral(".png"),
        QStringLiteral("/usr/share/pixmaps/") + iconName + QStringLiteral(".xpm"),
        QStringLiteral("/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps/") + iconName + QStringLiteral(".svg"),
        QStringLiteral("/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps/") + iconName + QStringLiteral(".png"),
        QStringLiteral("/var/lib/flatpak/exports/share/icons/hicolor/256x256/apps/") + iconName + QStringLiteral(".png"),
        QDir::homePath() + QStringLiteral("/.local/share/flatpak/exports/share/icons/hicolor/scalable/apps/") + iconName + QStringLiteral(".svg"),
        QDir::homePath() + QStringLiteral("/.local/share/flatpak/exports/share/icons/hicolor/128x128/apps/") + iconName + QStringLiteral(".png"),
        QDir::homePath() + QStringLiteral("/.local/share/flatpak/exports/share/icons/hicolor/256x256/apps/") + iconName + QStringLiteral(".png"),
    };

    for (const QString &hostPath : possiblePaths) {
        QProcess process;
        process.start(QStringLiteral("flatpak-spawn"),
                      {QStringLiteral("--host"), QStringLiteral("cat"), hostPath});

        if (!process.waitForFinished(3000)) {
            continue;
        }

        if (process.exitCode() != 0) {
            continue;
        }

        const QByteArray iconData = process.readAllStandardOutput();
        if (iconData.isEmpty()) {
            continue;
        }

        QString extension = QStringLiteral(".svg");
        if (hostPath.endsWith(QStringLiteral(".png"))) {
            extension = QStringLiteral(".png");
        } else if (hostPath.endsWith(QStringLiteral(".xpm"))) {
            extension = QStringLiteral(".xpm");
        }

        QString targetPath = cacheDir + QStringLiteral("/") + iconName + extension;

        QFile file(targetPath);
        if (file.open(QIODevice::WriteOnly)) {
            file.write(iconData);
            file.close();
            return targetPath;
        }
    }

    return {};
}

void ApplicationShortcutManager::scanDesktopFilesInDirectory(const QString &dirPath, QSet<QString> &processedIds)
{
    QDir dir(dirPath);
    if (!dir.exists()) {
        return;
    }

    QDirIterator it(dirPath, {QStringLiteral("*.desktop")}, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories | QDirIterator::FollowSymlinks);

    int filesFound = 0;
    int appsAdded = 0;
    int skippedDuplicate = 0;
    int skippedInvalid = 0;

    while (it.hasNext()) {
        const QString filePath = it.next();
        filesFound++;

        QVariantMap app = parseDesktopFile(filePath);

        if (app.isEmpty()) {
            skippedInvalid++;
            continue;
        }

        const QString desktopFileName = app[QStringLiteral("desktopFileName")].toString();
        if (processedIds.contains(desktopFileName)) {
            skippedDuplicate++;
            continue;
        }

        processedIds.insert(desktopFileName);
        m_applications.append(app);
        appsAdded++;
    }

    if (filesFound > 0) {
        qDebug() << "  Scanned" << dirPath << "- files:" << filesFound
                 << ", added:" << appsAdded
                 << ", duplicates:" << skippedDuplicate
                 << ", invalid:" << skippedInvalid;
    }
}

QVariantMap ApplicationShortcutManager::parseDesktopFile(const QString &filePath) const
{
    QFileInfo fileInfo(filePath);
    QString actualPath = filePath;

    if (fileInfo.isSymLink()) {
        actualPath = fileInfo.symLinkTarget();
        QFileInfo targetInfo(actualPath);
        if (!targetInfo.exists() || !targetInfo.isReadable()) {
            return {};
        }
    }

    QFile file(actualPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }

    QVariantMap result;
    QString currentGroup;
    bool inDesktopEntry = false;

    QString name;
    QString genericName;
    QString comment;
    QString icon;
    QString exec;
    QStringList categories;
    bool noDisplay = false;
    QString type;
    bool hidden = false;

    QTextStream in(&file);
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();

        if (line.isEmpty() || line.startsWith(QLatin1Char('#'))) {
            continue;
        }

        if (line.startsWith(QLatin1Char('[')) && line.endsWith(QLatin1Char(']'))) {
            currentGroup = line.mid(1, line.length() - 2);
            inDesktopEntry = (currentGroup == QStringLiteral("Desktop Entry"));
            continue;
        }

        if (!inDesktopEntry) {
            continue;
        }

        const int equalsPos = line.indexOf(QLatin1Char('='));
        if (equalsPos <= 0) {
            continue;
        }

        const QString key = line.left(equalsPos).trimmed();
        const QString value = line.mid(equalsPos + 1).trimmed();

        if (key == QStringLiteral("Type")) {
            type = value;
        } else if (key == QStringLiteral("Name")) {
            name = value;
        } else if (key == QStringLiteral("GenericName")) {
            genericName = value;
        } else if (key == QStringLiteral("Comment")) {
            comment = value;
        } else if (key == QStringLiteral("Icon")) {
            icon = value;
        } else if (key == QStringLiteral("Exec")) {
            exec = value;
        } else if (key == QStringLiteral("Categories")) {
            categories = value.split(QLatin1Char(';'), Qt::SkipEmptyParts);
        } else if (key == QStringLiteral("NoDisplay")) {
            noDisplay = (value.toLower() == QStringLiteral("true"));
        } else if (key == QStringLiteral("Hidden")) {
            hidden = (value.toLower() == QStringLiteral("true"));
        }
    }

    if (type != QStringLiteral("Application") || noDisplay || hidden || name.isEmpty()) {
        return {};
    }

    QFileInfo origFileInfo(filePath);
    QString desktopFileName = origFileInfo.completeBaseName();

    result[QStringLiteral("desktopFileName")] = desktopFileName;
    result[QStringLiteral("name")] = name;
    result[QStringLiteral("genericName")] = genericName;
    result[QStringLiteral("comment")] = comment;

    if (!isRunningInFlatpak() && filePath.contains(QStringLiteral("flatpak")) && !icon.isEmpty() && !icon.startsWith(QLatin1Char('/'))) {
        QString fullIconPath = findFlatpakIconPath(icon);
        result[QStringLiteral("icon")] = fullIconPath.isEmpty() ? icon : fullIconPath;
    } else {
        result[QStringLiteral("icon")] = icon;
    }

    result[QStringLiteral("exec")] = exec;
    result[QStringLiteral("categories")] = categories;
    result[QStringLiteral("desktopFilePath")] = filePath;

    return result;
}

QString ApplicationShortcutManager::findFlatpakIconPath(const QString &iconName) const
{
    if (iconName.isEmpty()) {
        return {};
    }

    const QStringList possiblePaths = {
        QDir::homePath() + QStringLiteral("/.local/share/flatpak/exports/share/icons/hicolor/scalable/apps/") + iconName + QStringLiteral(".svg"),
        QDir::homePath() + QStringLiteral("/.local/share/flatpak/exports/share/icons/hicolor/256x256/apps/") + iconName + QStringLiteral(".png"),
        QDir::homePath() + QStringLiteral("/.local/share/flatpak/exports/share/icons/hicolor/128x128/apps/") + iconName + QStringLiteral(".png"),
        QStringLiteral("/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps/") + iconName + QStringLiteral(".svg"),
        QStringLiteral("/var/lib/flatpak/exports/share/icons/hicolor/256x256/apps/") + iconName + QStringLiteral(".png"),
        QStringLiteral("/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps/") + iconName + QStringLiteral(".png"),
    };

    for (const QString &path : possiblePaths) {
        if (QFile::exists(path)) {
            return path;
        }
    }

    return {};
}

bool ApplicationShortcutManager::launchApplication(const QString &desktopFileName)
{
    qDebug() << "Attempting to launch application:" << desktopFileName;

    KService::Ptr service = KService::serviceByDesktopName(desktopFileName);

    if (service) {
        qDebug() << "Found KService for" << desktopFileName << "- using ApplicationLauncherJob";
        auto *job = new KIO::ApplicationLauncherJob(service);
        connect(job, &KJob::result, this, [this, desktopFileName](KJob *job) {
            if (job->error()) {
                qWarning() << "ApplicationLauncherJob failed:" << job->errorString();
                Q_EMIT launchError(job->errorString());
            } else {
                qDebug() << "Successfully launched via KService:" << desktopFileName;
                Q_EMIT applicationLaunched(desktopFileName);
            }
        });
        job->start();
        return true;
    }

    qDebug() << "KService not found, using fallback methods for:" << desktopFileName;

    for (const QVariant &app : m_applications) {
        QVariantMap appMap = app.toMap();
        if (appMap[QStringLiteral("desktopFileName")].toString() == desktopFileName) {
            QString desktopFilePath = appMap[QStringLiteral("desktopFilePath")].toString();

            if (!desktopFilePath.isEmpty()) {
                bool started = false;

                // Try flatpak-spawn with gtk-launch (best for sandboxed apps)
                if (isRunningInFlatpak()) {
                    qDebug() << "Running in Flatpak, trying: flatpak-spawn --host gtk-launch" << desktopFileName;
                    started = QProcess::startDetached(QStringLiteral("flatpak-spawn"),
                                                      {QStringLiteral("--host"),
                                                       QStringLiteral("gtk-launch"),
                                                       desktopFileName});
                    if (started) {
                        qDebug() << "Successfully launched via flatpak-spawn + gtk-launch";
                    }
                }

                // Try gtk-launch directly (works inside and outside Flatpak)
                if (!started) {
                    qDebug() << "Trying: gtk-launch" << desktopFileName;
                    started = QProcess::startDetached(QStringLiteral("gtk-launch"), {desktopFileName});
                    if (started) {
                        qDebug() << "Successfully launched via gtk-launch";
                    }
                }

                // Try kioclient exec as fallback
                if (!started) {
                    qDebug() << "Trying: kioclient exec" << desktopFilePath;
                    started = QProcess::startDetached(QStringLiteral("kioclient"),
                                                      {QStringLiteral("exec"),
                                                       desktopFilePath});
                    if (started) {
                        qDebug() << "Successfully launched via kioclient";
                    }
                }

                // Try kioclient5 for older KDE
                if (!started) {
                    qDebug() << "Trying: kioclient5 exec" << desktopFilePath;
                    started = QProcess::startDetached(QStringLiteral("kioclient5"),
                                                      {QStringLiteral("exec"),
                                                       desktopFilePath});
                    if (started) {
                        qDebug() << "Successfully launched via kioclient5";
                    }
                }

                if (started) {
                    Q_EMIT applicationLaunched(desktopFileName);
                    return true;
                }

                qWarning() << "All desktop file launch methods failed for:" << desktopFileName;
            }

            QString exec = appMap[QStringLiteral("exec")].toString();
            if (!exec.isEmpty()) {
                qDebug() << "Trying to execute Exec command:" << exec;
                exec.remove(QRegularExpression(QStringLiteral("%[fFuUdDnNickvm]")));
                exec = exec.trimmed();

                QStringList parts = QProcess::splitCommand(exec);
                if (!parts.isEmpty()) {
                    QString program = parts.takeFirst();

                    // Try with flatpak-spawn --host if running in Flatpak
                    bool started = false;
                    if (isRunningInFlatpak()) {
                        QStringList spawnArgs = {QStringLiteral("--host"), program};
                        spawnArgs.append(parts);
                        qDebug() << "Trying: flatpak-spawn --host" << program << parts.join(QStringLiteral(" "));
                        started = QProcess::startDetached(QStringLiteral("flatpak-spawn"), spawnArgs);
                        if (started) {
                            qDebug() << "Successfully launched via flatpak-spawn + exec";
                        }
                    }

                    // Try direct execution as fallback
                    if (!started) {
                        qDebug() << "Trying direct execution:" << program << parts.join(QStringLiteral(" "));
                        started = QProcess::startDetached(program, parts);
                        if (started) {
                            qDebug() << "Successfully launched via direct execution";
                        }
                    }

                    if (started) {
                        Q_EMIT applicationLaunched(desktopFileName);
                        return true;
                    }

                    qWarning() << "Failed to execute command:" << exec;
                }
            }

            break;
        }
    }

    const QString error = tr("Application not found: %1").arg(desktopFileName);
    qWarning() << error;
    Q_EMIT launchError(error);
    return false;
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
