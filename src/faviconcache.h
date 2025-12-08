#ifndef FAVICONCACHE_H
#define FAVICONCACHE_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QUrl>
#include <QDir>
#include <QHash>
#include <QTimer>

class FaviconCache : public QObject
{
    Q_OBJECT

public:
    explicit FaviconCache(QObject *parent = nullptr);

    Q_INVOKABLE QString getFavicon(const QString &serviceUrl, bool useFavicon);
    Q_INVOKABLE QString getImageUrl(const QString &imageUrl);
    Q_INVOKABLE void clearCache();

Q_SIGNALS:
    void faviconReady(const QString &serviceUrl, const QString &localPath);
    void imageReady(const QString &imageUrl, const QString &localPath);

private Q_SLOTS:
    void onFaviconDownloaded();
    void onImageDownloaded();

private:
    QString getCacheDir() const;
    QString getFaviconCachePath(const QString &hostname) const;
    QString getImageCachePath(const QString &imageUrl) const;
    QString extractHostname(const QString &serviceUrl) const;
    void downloadFavicon(const QString &serviceUrl, const QString &hostname);
    void downloadImage(const QString &imageUrl);
    QString hashUrl(const QString &url) const;

    QNetworkAccessManager *m_networkManager;
    QHash<QString, QString> m_faviconCache;
    QHash<QString, QString> m_imageCache;
    QSet<QString> m_pendingFavicons;
    QSet<QString> m_pendingImages;
    QString m_cacheDir;
};

#endif // FAVICONCACHE_H
