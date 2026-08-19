// SPDX-FileCopyrightText: 2025 Denys Madureira
// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TLSPROXYBRIDGE_H
#define TLSPROXYBRIDGE_H

#include <QJsonObject>
#include <QObject>
#include <QUrl>

class QNetworkAccessManager;
class QNetworkReply;
class QProcess;

// Bridge exposed to web pages via QWebChannel. Routes requests through the
// local cf-proxy.py sidecar, which re-issues them with a real browser TLS
// fingerprint to bypass Cloudflare's TLS-fingerprint bot detection.
class TlsProxyBridge : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool proxyReady READ proxyReady NOTIFY proxyReadyChanged)
    Q_PROPERTY(QStringList proxyHosts READ proxyHosts WRITE setProxyHosts NOTIFY proxyHostsChanged)
    Q_PROPERTY(QStringList learnedHosts READ learnedHosts NOTIFY learnedHostsChanged)

public:
    explicit TlsProxyBridge(QObject *parent = nullptr);
    ~TlsProxyBridge() override;

    bool proxyReady() const;

    // Hosts always routed through the proxy (source of truth: ConfigManager)
    QStringList proxyHosts() const;
    void setProxyHosts(const QStringList &hosts);

    // Hosts that needed a proxy retry to succeed, candidates for proxyHosts
    QStringList learnedHosts() const;
    Q_INVOKABLE void dismissLearnedHost(const QString &host);

    Q_INVOKABLE void fetchViaProxy(const QString &requestId, const QJsonObject &request);

    void setProxyBaseUrlForTesting(const QUrl &baseUrl);

Q_SIGNALS:
    void fetchResponse(const QString &requestId, const QJsonObject &response);
    void proxyReadyChanged();
    void proxyHostsChanged();
    void learnedHostsChanged();

private:
    void startSidecar();
    QString resolveProxyScriptPath() const;
    void setReady(bool ready);
    void learnHost(const QString &host);

    QNetworkAccessManager *m_networkManager;
    QProcess *m_process = nullptr;
    QString m_token;
    QUrl m_baseUrl;
    QStringList m_proxyHosts;
    QStringList m_learnedHosts;
    bool m_ready = false;
};

#endif // TLSPROXYBRIDGE_H
