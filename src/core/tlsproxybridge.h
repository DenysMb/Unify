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

public:
    explicit TlsProxyBridge(QObject *parent = nullptr);
    ~TlsProxyBridge() override;

    bool proxyReady() const;

    Q_INVOKABLE void fetchViaProxy(const QString &requestId, const QJsonObject &request);

    void setProxyBaseUrlForTesting(const QUrl &baseUrl);

Q_SIGNALS:
    void fetchResponse(const QString &requestId, const QJsonObject &response);
    void proxyReadyChanged();

private:
    void startSidecar();
    QString resolveProxyScriptPath() const;
    void setReady(bool ready);

    QNetworkAccessManager *m_networkManager;
    QProcess *m_process = nullptr;
    QString m_token;
    QUrl m_baseUrl;
    bool m_ready = false;
};

#endif // TLSPROXYBRIDGE_H
