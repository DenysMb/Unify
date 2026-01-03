#include "faviconcache.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QUrl>
#include <QDebug>

FaviconCache::FaviconCache(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
{
    m_cacheDir = getCacheDir();
    QDir().mkpath(m_cacheDir);
    QDir().mkpath(m_cacheDir + QStringLiteral("/favicons/google"));
    QDir().mkpath(m_cacheDir + QStringLiteral("/favicons/iconhorse"));
    QDir().mkpath(m_cacheDir + QStringLiteral("/images"));
}

QString FaviconCache::getCacheDir() const
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/icons");
}

QString FaviconCache::hashUrl(const QString &url) const
{
    return QString::fromLatin1(QCryptographicHash::hash(url.toUtf8(), QCryptographicHash::Md5).toHex());
}

QString FaviconCache::extractHostname(const QString &serviceUrl) const
{
    QUrl url(serviceUrl);
    if (url.isValid()) {
        return url.host();
    }
    return QString();
}

QString FaviconCache::extractRootDomain(const QString &hostname) const
{
    // Handle cases like "web.whatsapp.com" -> "whatsapp.com"
    // and "calendar.proton.me" -> "proton.me"
    QStringList parts = hostname.split(QLatin1Char('.'));

    if (parts.size() <= 2) {
        return hostname; // Already a root domain or invalid
    }

    // For domains like "web.whatsapp.com", return "whatsapp.com"
    // For domains like "calendar.proton.me", return "proton.me"
    return parts.mid(parts.size() - 2).join(QLatin1Char('.'));
}

QString FaviconCache::getFaviconCachePath(const QString &hostname, FaviconSource source) const
{
    QString sourceDir = source == GoogleSource ? QStringLiteral("google") : QStringLiteral("iconhorse");
    return m_cacheDir + QStringLiteral("/favicons/") + sourceDir + QLatin1Char('/') + hashUrl(hostname) + QStringLiteral(".png");
}

QString FaviconCache::getImageCachePath(const QString &imageUrl) const
{
    QUrl url(imageUrl);
    QString extension = QFileInfo(url.path()).suffix();
    if (extension.isEmpty()) {
        extension = QStringLiteral("png");
    }
    return m_cacheDir + QStringLiteral("/images/") + hashUrl(imageUrl) + QStringLiteral(".") + extension;
}

QString FaviconCache::getFavicon(const QString &serviceUrl, bool useFavicon)
{
    if (!useFavicon || serviceUrl.isEmpty()) {
        return QString();
    }

    QString hostname = extractHostname(serviceUrl);
    if (hostname.isEmpty()) {
        return QString();
    }

    // Check Google favicon cache first
    QString googleCachePath = getFaviconCachePath(hostname, GoogleSource);
    if (QFile::exists(googleCachePath)) {
        QString localUrl = QStringLiteral("file://") + googleCachePath;
        m_faviconCache.insert(hostname, localUrl);
        m_googleFaviconCache.insert(hostname, localUrl);
        return localUrl;
    }

    // Start download with fallback
    downloadFavicon(serviceUrl, hostname, GoogleWithFallback);
    return QString();
}

QString FaviconCache::getFaviconForSource(const QString &serviceUrl, FaviconSource source)
{
    if (serviceUrl.isEmpty()) {
        return QString();
    }

    QString hostname = extractHostname(serviceUrl);
    if (hostname.isEmpty()) {
        return QString();
    }

    QString cachePath = getFaviconCachePath(hostname, source);

    // Check memory cache
    QHash<QString, QString> &sourceCache = source == GoogleSource ? m_googleFaviconCache : m_iconHorseFaviconCache;
    if (sourceCache.contains(hostname)) {
        return sourceCache.value(hostname);
    }

    // Check disk cache
    if (QFile::exists(cachePath)) {
        QString localUrl = QStringLiteral("file://") + cachePath;
        sourceCache.insert(hostname, localUrl);
        return localUrl;
    }

    return QString();
}

void FaviconCache::fetchFaviconFromSource(const QString &serviceUrl, FaviconSource source)
{
    if (serviceUrl.isEmpty()) {
        return;
    }

    QString hostname = extractHostname(serviceUrl);
    if (hostname.isEmpty()) {
        return;
    }

    QString cachePath = getFaviconCachePath(hostname, source);

    // Check if already cached
    QHash<QString, QString> &sourceCache = source == GoogleSource ? m_googleFaviconCache : m_iconHorseFaviconCache;
    if (sourceCache.contains(hostname) || QFile::exists(cachePath)) {
        QString localUrl = QStringLiteral("file://") + cachePath;
        sourceCache.insert(hostname, localUrl);
        Q_EMIT faviconSourceReady(serviceUrl, static_cast<int>(source), localUrl);
        return;
    }

    // Try subdomain first
    FaviconFetchType fetchType = source == GoogleSource ? GoogleSubdomainOnly : IconHorseSubdomainOnly;
    downloadFavicon(serviceUrl, hostname, fetchType);
}

QString FaviconCache::getImageUrl(const QString &imageUrl)
{
    if (imageUrl.isEmpty()) {
        return QString();
    }

    if (!imageUrl.startsWith(QStringLiteral("http://")) && !imageUrl.startsWith(QStringLiteral("https://"))) {
        return imageUrl;
    }

    QString cachePath = getImageCachePath(imageUrl);

    if (m_imageCache.contains(imageUrl)) {
        return m_imageCache.value(imageUrl);
    }

    if (QFile::exists(cachePath)) {
        m_imageCache.insert(imageUrl, QStringLiteral("file://") + cachePath);
        return m_imageCache.value(imageUrl);
    }

    downloadImage(imageUrl);
    return QString();
}

void FaviconCache::downloadFavicon(const QString &serviceUrl, const QString &hostname, FaviconFetchType fetchType)
{
    // Create a unique key for tracking pending requests
    QString fetchKeyString = hostname + QLatin1Char('_') + QString::number(static_cast<int>(fetchType));
    if (m_pendingFavicons.contains(fetchKeyString)) {
        return;
    }

    m_pendingFavicons.insert(fetchKeyString);
    m_fetchKeyToString.insert(fetchKeyString, fetchKeyString);

    QString faviconUrl;

    switch (fetchType) {
    case GoogleWithFallback:
    case GoogleSubdomainOnly:
        faviconUrl = QStringLiteral("https://www.google.com/s2/favicons?domain=%1&sz=128").arg(hostname);
        break;
    case GoogleRootDomainOnly: {
        QString rootDomain = extractRootDomain(hostname);
        faviconUrl = QStringLiteral("https://www.google.com/s2/favicons?domain=%1&sz=128").arg(rootDomain);
        break;
    }
    case IconHorseSubdomainOnly:
        faviconUrl = QStringLiteral("https://icon.horse/icon/%1?size=128").arg(hostname);
        break;
    case IconHorseRootDomainOnly: {
        QString rootDomain = extractRootDomain(hostname);
        faviconUrl = QStringLiteral("https://icon.horse/icon/%1?size=128").arg(rootDomain);
        break;
    }
    }

    QUrl url(faviconUrl);
    QNetworkRequest request{url};
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setRawHeader("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:145.0) Gecko/20100101 Firefox/145.0");

    QNetworkReply *reply = m_networkManager->get(request);
    reply->setProperty("hostname", hostname);
    reply->setProperty("serviceUrl", serviceUrl);
    reply->setProperty("fetchType", static_cast<int>(fetchType));
    reply->setProperty("fetchKeyString", fetchKeyString);

    connect(reply, &QNetworkReply::finished, this, &FaviconCache::onFaviconDownloaded);
}

void FaviconCache::downloadImage(const QString &imageUrl)
{
    if (m_pendingImages.contains(imageUrl)) {
        return;
    }

    m_pendingImages.insert(imageUrl);

    QUrl url(imageUrl);
    QNetworkRequest request{url};
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setRawHeader("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:145.0) Gecko/20100101 Firefox/145.0");

    QNetworkReply *reply = m_networkManager->get(request);
    reply->setProperty("imageUrl", imageUrl);

    connect(reply, &QNetworkReply::finished, this, &FaviconCache::onImageDownloaded);
}

void FaviconCache::onFaviconDownloaded()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply) {
        return;
    }

    QString hostname = reply->property("hostname").toString();
    QString serviceUrl = reply->property("serviceUrl").toString();
    int fetchTypeInt = reply->property("fetchType").toInt();
    FaviconFetchType fetchType = static_cast<FaviconFetchType>(fetchTypeInt);
    QString fetchKeyString = reply->property("fetchKeyString").toString();

    m_pendingFavicons.remove(fetchKeyString);
    m_fetchKeyToString.remove(fetchKeyString);

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        if (!data.isEmpty()) {
            // Determine the source based on fetch type
            FaviconSource source =
                (fetchType == GoogleSubdomainOnly || fetchType == GoogleRootDomainOnly || fetchType == GoogleWithFallback) ? GoogleSource : IconHorseSource;

            QString cachePath = getFaviconCachePath(hostname, source);
            QFile file(cachePath);
            if (file.open(QIODevice::WriteOnly)) {
                file.write(data);
                file.close();

                QString localUrl = QStringLiteral("file://") + cachePath;

                // Update appropriate cache
                if (source == GoogleSource) {
                    m_googleFaviconCache.insert(hostname, localUrl);
                } else {
                    m_iconHorseFaviconCache.insert(hostname, localUrl);
                }
                m_faviconCache.insert(hostname, localUrl);

                // Emit both signals
                Q_EMIT faviconReady(serviceUrl, localUrl);
                Q_EMIT faviconSourceReady(serviceUrl, static_cast<int>(source), localUrl);
            }
        }
    } else {
        qWarning() << "Failed to download favicon for" << hostname << "from source" << fetchTypeInt << ":" << reply->errorString();

        // If this was GoogleSubdomainOnly and it failed, try root domain
        if (fetchType == GoogleSubdomainOnly) {
            QString rootDomain = extractRootDomain(hostname);
            if (rootDomain != hostname) {
                qDebug() << "Falling back from subdomain" << hostname << "to root domain" << rootDomain;
                downloadFavicon(serviceUrl, hostname, GoogleRootDomainOnly);
            }
        }
    }

    reply->deleteLater();
}

void FaviconCache::onImageDownloaded()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply) {
        return;
    }

    QString imageUrl = reply->property("imageUrl").toString();

    m_pendingImages.remove(imageUrl);

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        if (!data.isEmpty()) {
            QString cachePath = getImageCachePath(imageUrl);
            QFile file(cachePath);
            if (file.open(QIODevice::WriteOnly)) {
                file.write(data);
                file.close();

                QString localUrl = QStringLiteral("file://") + cachePath;
                m_imageCache.insert(imageUrl, localUrl);
                Q_EMIT imageReady(imageUrl, localUrl);
            }
        }
    } else {
        qWarning() << "Failed to download image" << imageUrl << ":" << reply->errorString();
    }

    reply->deleteLater();
}

void FaviconCache::clearCache()
{
    m_faviconCache.clear();
    m_googleFaviconCache.clear();
    m_iconHorseFaviconCache.clear();
    m_imageCache.clear();

    QDir faviconDir(m_cacheDir + QStringLiteral("/favicons"));
    faviconDir.removeRecursively();

    QDir imageDir(m_cacheDir + QStringLiteral("/images"));
    imageDir.removeRecursively();

    QDir().mkpath(m_cacheDir + QStringLiteral("/favicons/google"));
    QDir().mkpath(m_cacheDir + QStringLiteral("/favicons/iconhorse"));
    QDir().mkpath(m_cacheDir + QStringLiteral("/images"));
}
