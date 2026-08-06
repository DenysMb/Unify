// SPDX-FileCopyrightText: 2025 Denys Madureira
// SPDX-License-Identifier: GPL-3.0-or-later

#include "tlsproxybridge.h"

#include <QCoreApplication>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QStandardPaths>
#include <QUuid>

namespace
{
constexpr int REQUEST_TIMEOUT_MS = 45000;
}

TlsProxyBridge::TlsProxyBridge(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_token(QUuid::createUuid().toString(QUuid::WithoutBraces))
{
    startSidecar();
}

TlsProxyBridge::~TlsProxyBridge()
{
    if (m_process) {
        m_process->kill();
        m_process->waitForFinished(2000);
    }
}

bool TlsProxyBridge::proxyReady() const
{
    return m_ready;
}

QStringList TlsProxyBridge::proxyHosts() const
{
    return m_proxyHosts;
}

void TlsProxyBridge::setProxyHosts(const QStringList &hosts)
{
    if (m_proxyHosts == hosts) {
        return;
    }
    m_proxyHosts = hosts;
    Q_EMIT proxyHostsChanged();
}

QStringList TlsProxyBridge::learnedHosts() const
{
    return m_learnedHosts;
}

void TlsProxyBridge::dismissLearnedHost(const QString &host)
{
    if (m_learnedHosts.removeAll(host) > 0) {
        Q_EMIT learnedHostsChanged();
    }
}

void TlsProxyBridge::learnHost(const QString &host)
{
    if (host.isEmpty() || m_proxyHosts.contains(host) || m_learnedHosts.contains(host)) {
        return;
    }
    m_learnedHosts.append(host);
    Q_EMIT learnedHostsChanged();
}

void TlsProxyBridge::setProxyBaseUrlForTesting(const QUrl &baseUrl)
{
    m_baseUrl = baseUrl;
    setReady(true);
}

void TlsProxyBridge::setReady(bool ready)
{
    if (m_ready == ready) {
        return;
    }
    m_ready = ready;
    Q_EMIT proxyReadyChanged();
}

QString TlsProxyBridge::resolveProxyScriptPath() const
{
    QStringList candidates;
    const QString fromEnv = qEnvironmentVariable("UNIFY_PROXY_SCRIPT");
    if (!fromEnv.isEmpty()) {
        candidates << fromEnv;
    }
    const QString appDir = QCoreApplication::applicationDirPath();
    candidates << appDir + QStringLiteral("/../share/unify/cf-proxy.py");
    candidates << appDir + QStringLiteral("/cf-proxy.py");
#ifdef UNIFY_SOURCE_DIR
    candidates << QStringLiteral(UNIFY_SOURCE_DIR) + QStringLiteral("/src/proxy/cf-proxy.py");
#endif
    for (const QString &candidate : std::as_const(candidates)) {
        if (QFileInfo::exists(candidate)) {
            return candidate;
        }
    }
    return QString();
}

void TlsProxyBridge::startSidecar()
{
    const QString scriptPath = resolveProxyScriptPath();
    if (scriptPath.isEmpty()) {
        qWarning() << "TlsProxyBridge: cf-proxy.py not found, TLS proxy disabled";
        return;
    }
    const QString python = QStandardPaths::findExecutable(QStringLiteral("python3"));
    if (python.isEmpty()) {
        qWarning() << "TlsProxyBridge: python3 not found, TLS proxy disabled";
        return;
    }

    m_process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert(QStringLiteral("UNIFY_PROXY_TOKEN"), m_token);
    m_process->setProcessEnvironment(env);
    m_process->setProgram(python);
    m_process->setArguments({scriptPath});

    connect(m_process, &QProcess::readyReadStandardOutput, this, [this]() {
        while (m_process->canReadLine()) {
            const QString line = QString::fromUtf8(m_process->readLine()).trimmed();
            if (line.startsWith(QStringLiteral("PORT="))) {
                bool ok = false;
                const quint16 port = line.mid(5).toUShort(&ok);
                if (ok && port > 0) {
                    m_baseUrl = QUrl(QStringLiteral("http://127.0.0.1:%1/").arg(port));
                    qInfo() << "TlsProxyBridge: sidecar proxy listening on port" << port;
                    setReady(true);
                }
            } else if (line.startsWith(QStringLiteral("ERROR="))) {
                qWarning() << "TlsProxyBridge: sidecar failed:" << line.mid(6);
            }
        }
    });
    connect(m_process, &QProcess::readyReadStandardError, this, [this]() {
        const QString output = QString::fromUtf8(m_process->readAllStandardError()).trimmed();
        if (!output.isEmpty()) {
            qWarning() << "TlsProxyBridge sidecar:" << output;
        }
    });
    connect(m_process, &QProcess::finished, this, [this](int exitCode, QProcess::ExitStatus) {
        qWarning() << "TlsProxyBridge: sidecar exited with code" << exitCode;
        setReady(false);
    });

    m_process->start();
}

void TlsProxyBridge::fetchViaProxy(const QString &requestId, const QJsonObject &request)
{
    if (!m_ready) {
        Q_EMIT fetchResponse(requestId, {{QStringLiteral("error"), QStringLiteral("proxy-unavailable")}});
        return;
    }

    const QString targetUrl = request.value(QStringLiteral("url")).toString();
    const QString method = request.value(QStringLiteral("method")).toString().toUpper();
    if (!targetUrl.startsWith(QStringLiteral("https://")) || method.isEmpty()) {
        Q_EMIT fetchResponse(requestId, {{QStringLiteral("error"), QStringLiteral("invalid-request")}});
        return;
    }

    QNetworkRequest networkRequest(m_baseUrl);
    networkRequest.setRawHeader("X-Unify-Token", m_token.toUtf8());
    networkRequest.setRawHeader("X-Unify-Target-Url", targetUrl.toUtf8());
    networkRequest.setTransferTimeout(REQUEST_TIMEOUT_MS);

    const QJsonObject headers = request.value(QStringLiteral("headers")).toObject();
    for (auto it = headers.begin(); it != headers.end(); ++it) {
        const QByteArray name = it.key().toUtf8();
        const QByteArray lowered = name.toLower();
        if (lowered == "host" || lowered == "content-length" || lowered == "connection") {
            continue;
        }
        networkRequest.setRawHeader(name, it.value().toString().toUtf8());
    }

    const QByteArray body = QByteArray::fromBase64(request.value(QStringLiteral("bodyBase64")).toString().toUtf8());
    QNetworkReply *reply = m_networkManager->sendCustomRequest(networkRequest, method.toUtf8(), body);

    // Generic-fallback retries that succeed reveal hosts gated by TLS fingerprint
    const QString retryHost = request.value(QStringLiteral("isRetry")).toBool() ? QUrl(targetUrl).host() : QString();

    connect(reply, &QNetworkReply::finished, this, [this, reply, requestId, retryHost]() {
        reply->deleteLater();
        QJsonObject response;
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status > 0) {
            learnHost(retryHost);
            // An HTTP response arrived, even if Qt flags 4xx/5xx as a reply error
            response.insert(QStringLiteral("status"), status);
            QJsonObject responseHeaders;
            const QList<QNetworkReply::RawHeaderPair> rawPairs = reply->rawHeaderPairs();
            for (const auto &pair : rawPairs) {
                responseHeaders.insert(QString::fromUtf8(pair.first).toLower(), QString::fromUtf8(pair.second));
            }
            response.insert(QStringLiteral("headers"), responseHeaders);
            response.insert(QStringLiteral("bodyBase64"), QString::fromUtf8(reply->readAll().toBase64()));
        } else {
            response.insert(QStringLiteral("error"), reply->errorString());
        }
        Q_EMIT fetchResponse(requestId, response);
    });
}
