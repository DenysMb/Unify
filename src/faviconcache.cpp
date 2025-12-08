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
    QDir().mkpath(m_cacheDir + QStringLiteral("/favicons"));
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

QString FaviconCache::getFaviconCachePath(const QString &hostname) const
{
    return m_cacheDir + QStringLiteral("/favicons/") + hashUrl(hostname) + QStringLiteral(".png");
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

    QString cachePath = getFaviconCachePath(hostname);
    
    if (m_faviconCache.contains(hostname)) {
        return m_faviconCache.value(hostname);
    }

    if (QFile::exists(cachePath)) {
        m_faviconCache.insert(hostname, QStringLiteral("file://") + cachePath);
        return m_faviconCache.value(hostname);
    }

    downloadFavicon(serviceUrl, hostname);
    return QString();
}

QString FaviconCache::getImageUrl(const QString &imageUrl)
{
    if (imageUrl.isEmpty()) {
        return QString();
    }

    if (!imageUrl.startsWith(QStringLiteral("http://")) && 
        !imageUrl.startsWith(QStringLiteral("https://"))) {
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

void FaviconCache::downloadFavicon(const QString &serviceUrl, const QString &hostname)
{
    if (m_pendingFavicons.contains(hostname)) {
        return;
    }

    m_pendingFavicons.insert(hostname);

    QString faviconUrl = QStringLiteral("https://www.google.com/s2/favicons?domain=%1&sz=128").arg(hostname);
    
    QUrl url(faviconUrl);
    QNetworkRequest request{url};
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setRawHeader("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:145.0) Gecko/20100101 Firefox/145.0");
    
    QNetworkReply *reply = m_networkManager->get(request);
    reply->setProperty("hostname", hostname);
    reply->setProperty("serviceUrl", serviceUrl);
    
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
    
    m_pendingFavicons.remove(hostname);

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        if (!data.isEmpty()) {
            QString cachePath = getFaviconCachePath(hostname);
            QFile file(cachePath);
            if (file.open(QIODevice::WriteOnly)) {
                file.write(data);
                file.close();
                
                QString localUrl = QStringLiteral("file://") + cachePath;
                m_faviconCache.insert(hostname, localUrl);
                Q_EMIT faviconReady(serviceUrl, localUrl);
            }
        }
    } else {
        qWarning() << "Failed to download favicon for" << hostname << ":" << reply->errorString();
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
    m_imageCache.clear();
    
    QDir faviconDir(m_cacheDir + QStringLiteral("/favicons"));
    faviconDir.removeRecursively();
    
    QDir imageDir(m_cacheDir + QStringLiteral("/images"));
    imageDir.removeRecursively();
    
    QDir().mkpath(m_cacheDir + QStringLiteral("/favicons"));
    QDir().mkpath(m_cacheDir + QStringLiteral("/images"));
}
