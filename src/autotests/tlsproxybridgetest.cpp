// SPDX-FileCopyrightText: 2025 Denys Madureira
// SPDX-License-Identifier: GPL-3.0-or-later

#include "core/tlsproxybridge.h"

#include <QSignalSpy>
#include <QTcpServer>
#include <QTcpSocket>
#include <QtTest>

class TlsProxyBridgeTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void init();
    void fetchRoundTrip();
    void httpErrorStatusIsForwarded();
    void learnsSuccessfulRetryHosts();
    void unavailableWithoutSidecar();
};

void TlsProxyBridgeTest::init()
{
    qputenv("UNIFY_PROXY_SCRIPT", "/nonexistent/cf-proxy.py");
}

void TlsProxyBridgeTest::fetchRoundTrip()
{
    QTcpServer server;
    QVERIFY(server.listen(QHostAddress::LocalHost));

    TlsProxyBridge bridge;
    bridge.setProxyBaseUrlForTesting(QUrl(QStringLiteral("http://127.0.0.1:%1/").arg(server.serverPort())));
    QVERIFY(bridge.proxyReady());

    QSignalSpy spy(&bridge, &TlsProxyBridge::fetchResponse);
    QJsonObject headers{{QStringLiteral("Content-Type"), QStringLiteral("application/json")},
                        {QStringLiteral("Authorization"), QStringLiteral("Bearer token123")}};
    QJsonObject request{{QStringLiteral("url"), QStringLiteral("https://api.example.com/v2/login")},
                        {QStringLiteral("method"), QStringLiteral("POST")},
                        {QStringLiteral("headers"), headers},
                        {QStringLiteral("bodyBase64"), QString::fromUtf8(QByteArray("{\"email\":\"a@b.c\"}").toBase64())}};
    bridge.fetchViaProxy(QStringLiteral("req-1"), request);

    QTRY_VERIFY_WITH_TIMEOUT(server.hasPendingConnections(), 5000);
    QTcpSocket *socket = server.nextPendingConnection();
    QVERIFY(socket);

    QByteArray raw;
    QTRY_VERIFY_WITH_TIMEOUT((raw += socket->readAll(), raw.indexOf("\r\n\r\n") > 0), 5000);
    const int headerEnd = raw.indexOf("\r\n\r\n");

    QByteArray targetUrl;
    QByteArray token;
    QByteArray authorization;
    int contentLength = -1;
    const QList<QByteArray> lines = raw.left(headerEnd).split('\n');
    for (const QByteArray &line : lines) {
        const QByteArray trimmed = line.trimmed();
        const int colon = trimmed.indexOf(':');
        if (colon < 0) {
            continue;
        }
        const QByteArray name = trimmed.left(colon).toLower();
        const QByteArray value = trimmed.mid(colon + 1).trimmed();
        if (name == "x-unify-target-url") {
            targetUrl = value;
        } else if (name == "x-unify-token") {
            token = value;
        } else if (name == "authorization") {
            authorization = value;
        } else if (name == "content-length") {
            contentLength = value.toInt();
        }
    }
    QCOMPARE(targetUrl, QByteArray("https://api.example.com/v2/login"));
    QVERIFY(!token.isEmpty());
    QCOMPARE(authorization, QByteArray("Bearer token123"));
    QVERIFY(contentLength > 0);

    QTRY_VERIFY_WITH_TIMEOUT((raw += socket->readAll(), raw.size() >= headerEnd + 4 + contentLength), 5000);
    const QByteArray body = raw.mid(headerEnd + 4);
    QCOMPARE(body, QByteArray("{\"email\":\"a@b.c\"}"));

    const QByteArray responseBody = "hello-world";
    socket->write("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nX-Test-Header: works\r\nContent-Length: " + QByteArray::number(responseBody.size())
                  + "\r\n\r\n" + responseBody);
    socket->flush();

    QVERIFY(spy.wait(5000));
    QCOMPARE(spy.count(), 1);
    const QList<QVariant> args = spy.takeFirst();
    QCOMPARE(args.at(0).toString(), QStringLiteral("req-1"));
    const QJsonObject response = args.at(1).toJsonObject();
    QCOMPARE(response.value(QStringLiteral("status")).toInt(), 200);
    QCOMPARE(response.value(QStringLiteral("headers")).toObject().value(QStringLiteral("x-test-header")).toString(), QStringLiteral("works"));
    const QByteArray decoded = QByteArray::fromBase64(response.value(QStringLiteral("bodyBase64")).toString().toUtf8());
    QCOMPARE(decoded, QByteArray("hello-world"));

    socket->disconnectFromHost();
}

void TlsProxyBridgeTest::httpErrorStatusIsForwarded()
{
    QTcpServer server;
    QVERIFY(server.listen(QHostAddress::LocalHost));

    TlsProxyBridge bridge;
    bridge.setProxyBaseUrlForTesting(QUrl(QStringLiteral("http://127.0.0.1:%1/").arg(server.serverPort())));

    QSignalSpy spy(&bridge, &TlsProxyBridge::fetchResponse);
    QJsonObject request{{QStringLiteral("url"), QStringLiteral("https://api.example.com/v2/login-params")},
                        {QStringLiteral("method"), QStringLiteral("POST")},
                        {QStringLiteral("headers"), QJsonObject{}},
                        {QStringLiteral("bodyBase64"), QString()}};
    bridge.fetchViaProxy(QStringLiteral("req-2"), request);

    QTRY_VERIFY_WITH_TIMEOUT(server.hasPendingConnections(), 5000);
    QTcpSocket *socket = server.nextPendingConnection();
    QVERIFY(socket);

    QByteArray raw;
    QTRY_VERIFY_WITH_TIMEOUT((raw += socket->readAll(), raw.indexOf("\r\n\r\n") > 0), 5000);

    const QByteArray responseBody = "{\"error\":{\"message\":\"Invalid credentials\"}}";
    socket->write("HTTP/1.1 401 Unauthorized\r\nContent-Type: application/json\r\nContent-Length: " + QByteArray::number(responseBody.size()) + "\r\n\r\n"
                  + responseBody);
    socket->flush();

    QVERIFY(spy.wait(5000));
    QCOMPARE(spy.count(), 1);
    const QJsonObject response = spy.takeFirst().at(1).toJsonObject();
    QVERIFY(!response.contains(QStringLiteral("error")));
    QCOMPARE(response.value(QStringLiteral("status")).toInt(), 401);
    const QByteArray decoded = QByteArray::fromBase64(response.value(QStringLiteral("bodyBase64")).toString().toUtf8());
    QCOMPARE(decoded, responseBody);

    socket->disconnectFromHost();
}

void TlsProxyBridgeTest::learnsSuccessfulRetryHosts()
{
    QTcpServer server;
    QVERIFY(server.listen(QHostAddress::LocalHost));

    TlsProxyBridge bridge;
    bridge.setProxyBaseUrlForTesting(QUrl(QStringLiteral("http://127.0.0.1:%1/").arg(server.serverPort())));

    QSignalSpy spy(&bridge, &TlsProxyBridge::fetchResponse);
    QJsonObject request{{QStringLiteral("url"), QStringLiteral("https://gated.example.com/api")},
                        {QStringLiteral("method"), QStringLiteral("GET")},
                        {QStringLiteral("isRetry"), true}};
    bridge.fetchViaProxy(QStringLiteral("req-3"), request);

    QTRY_VERIFY_WITH_TIMEOUT(server.hasPendingConnections(), 5000);
    QTcpSocket *socket = server.nextPendingConnection();
    QVERIFY(socket);

    QByteArray raw;
    QTRY_VERIFY_WITH_TIMEOUT((raw += socket->readAll(), raw.indexOf("\r\n\r\n") > 0), 5000);
    socket->write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n");
    socket->flush();

    QVERIFY(spy.wait(5000));
    QCOMPARE(bridge.learnedHosts(), QStringList{QStringLiteral("gated.example.com")});

    bridge.dismissLearnedHost(QStringLiteral("gated.example.com"));
    QVERIFY(bridge.learnedHosts().isEmpty());

    socket->disconnectFromHost();
}

void TlsProxyBridgeTest::unavailableWithoutSidecar()
{
    TlsProxyBridge bridge;
    QVERIFY(!bridge.proxyReady());

    QSignalSpy spy(&bridge, &TlsProxyBridge::fetchResponse);
    bridge.fetchViaProxy(QStringLiteral("req-x"), {});
    QCOMPARE(spy.count(), 1);
    const QJsonObject response = spy.takeFirst().at(1).toJsonObject();
    QCOMPARE(response.value(QStringLiteral("error")).toString(), QStringLiteral("proxy-unavailable"));
}

QTEST_MAIN(TlsProxyBridgeTest)
#include "tlsproxybridgetest.moc"
