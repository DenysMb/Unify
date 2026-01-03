#ifndef FAVICONCACHE_H
#define FAVICONCACHE_H

#include <QDir>
#include <QHash>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QSet>
#include <QTimer>
#include <QUrl>

class FaviconCache : public QObject
{
    Q_OBJECT

public:
    enum FaviconSource {
        GoogleSource,
        IconHorseSource
    };
    Q_ENUM(FaviconSource)

    explicit FaviconCache(QObject *parent = nullptr);

    Q_INVOKABLE QString getFavicon(const QString &serviceUrl, bool useFavicon);
    Q_INVOKABLE QString getFaviconForSource(const QString &serviceUrl, FaviconSource source);
    Q_INVOKABLE void fetchFaviconFromSource(const QString &serviceUrl, FaviconSource source);
    Q_INVOKABLE QString getImageUrl(const QString &imageUrl);
    Q_INVOKABLE void clearCache();

Q_SIGNALS:
    void faviconReady(const QString &serviceUrl, const QString &localPath);
    void faviconSourceReady(const QString &serviceUrl, int source, const QString &localPath);
    void imageReady(const QString &imageUrl, const QString &localPath);

private Q_SLOTS:
    void onFaviconDownloaded();
    void onImageDownloaded();

private:
    enum FaviconFetchType {
        GoogleWithFallback, // Try subdomain, then root domain
        GoogleSubdomainOnly, // Try subdomain only
        GoogleRootDomainOnly, // Try root domain only
        IconHorseSubdomainOnly, // Try subdomain only via IconHorse
        IconHorseRootDomainOnly // Try root domain only via IconHorse
    };

    QString getCacheDir() const;
    QString getFaviconCachePath(const QString &hostname, FaviconSource source) const;
    QString getImageCachePath(const QString &imageUrl) const;
    QString extractHostname(const QString &serviceUrl) const;
    QString extractRootDomain(const QString &hostname) const;
    void downloadFavicon(const QString &serviceUrl, const QString &hostname, FaviconFetchType fetchType);
    void downloadImage(const QString &imageUrl);
    QString hashUrl(const QString &url) const;

    QNetworkAccessManager *m_networkManager;
    QHash<QString, QString> m_faviconCache;
    QHash<QString, QString> m_googleFaviconCache;
    QHash<QString, QString> m_iconHorseFaviconCache;
    QHash<QString, QString> m_imageCache;
    QHash<QString, QString> m_fetchKeyToString;
    QSet<QString> m_pendingFavicons;
    QSet<QString> m_pendingImages;
    QString m_cacheDir;
};

#endif // FAVICONCACHE_H
