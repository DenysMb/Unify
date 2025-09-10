#include "oauthmanager.h"
#include <QDesktopServices>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>
#include <QUrlQuery>

// Google OAuth2 constants
const QString OAuthManager::GOOGLE_CLIENT_ID = QStringLiteral("YOUR_CLIENT_ID"); // Placeholder - needs real client ID
const QString OAuthManager::GOOGLE_CLIENT_SECRET = QStringLiteral("YOUR_CLIENT_SECRET"); // Placeholder
const QString OAuthManager::GOOGLE_AUTH_URL = QStringLiteral("https://accounts.google.com/o/oauth2/v2/auth");
const QString OAuthManager::GOOGLE_TOKEN_URL = QStringLiteral("https://oauth2.googleapis.com/token");
const QString OAuthManager::GOOGLE_USERINFO_URL = QStringLiteral("https://www.googleapis.com/oauth2/v2/userinfo");
const QString OAuthManager::GOOGLE_SCOPE = QStringLiteral("openid email profile");

OAuthManager::OAuthManager(QObject *parent)
    : QObject(parent)
    , m_googleFlow(nullptr)
    , m_replyHandler(nullptr)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_isAuthenticated(false)
{
    setupGoogleOAuth();
}

void OAuthManager::setupGoogleOAuth()
{
    m_googleFlow = new QOAuth2AuthorizationCodeFlow(this);
    
    // Set up OAuth2 endpoints and credentials
    m_googleFlow->setAuthorizationUrl(QUrl(GOOGLE_AUTH_URL));
    m_googleFlow->setTokenUrl(QUrl(GOOGLE_TOKEN_URL)); // Use new API
    m_googleFlow->setClientIdentifier(GOOGLE_CLIENT_ID);
    m_googleFlow->setClientIdentifierSharedKey(GOOGLE_CLIENT_SECRET);
    
    // Set scope using new property-based API
    QStringList scopesList = GOOGLE_SCOPE.split(QStringLiteral(" "), Qt::SkipEmptyParts);
    QSet<QByteArray> scopes;
    for (const QString &scope : scopesList) {
        scopes.insert(scope.toUtf8());
    }
    m_googleFlow->setRequestedScopeTokens(scopes);
    
    // Set up reply handler (localhost server for redirect)
    m_replyHandler = new QOAuthHttpServerReplyHandler(8080, this);
    m_googleFlow->setReplyHandler(m_replyHandler);
    
    // Connect to open browser for authorization
    connect(m_googleFlow, &QOAuth2AuthorizationCodeFlow::authorizeWithBrowser, 
            &QDesktopServices::openUrl);
    
    // Connect status and token changes
    connect(m_googleFlow, &QOAuth2AuthorizationCodeFlow::statusChanged,
            this, &OAuthManager::onStatusChanged);
    connect(m_googleFlow, &QOAuth2AuthorizationCodeFlow::tokenChanged,
            this, &OAuthManager::onTokenChanged);
    connect(m_googleFlow, &QOAuth2AuthorizationCodeFlow::granted,
            this, &OAuthManager::onGranted);
    
    qDebug() << "✅ OAuth2 Manager initialized with Google configuration";
}

bool OAuthManager::isAuthenticated() const
{
    return m_isAuthenticated;
}

QString OAuthManager::userEmail() const
{
    return m_userEmail;
}

QString OAuthManager::userName() const
{
    return m_userName;
}

void OAuthManager::authenticateWithGoogle()
{
    qDebug() << "🔐 Starting Google OAuth2 authentication";
    
    if (m_googleFlow) {
        m_googleFlow->grant();
    } else {
        Q_EMIT authenticationFailed(QStringLiteral("OAuth flow not initialized"));
    }
}

void OAuthManager::logout()
{
    qDebug() << "🚪 Logging out user";
    
    m_isAuthenticated = false;
    m_userEmail.clear();
    m_userName.clear();
    m_accessToken.clear();
    
    // Note: QOAuth2AuthorizationCodeFlow doesn't have reset() method
    // Just clear tokens manually
    
    Q_EMIT authenticationChanged();
    Q_EMIT userInfoChanged();
}

void OAuthManager::onStatusChanged(QAbstractOAuth::Status status)
{
    QString statusText;
    switch (status) {
        case QAbstractOAuth::Status::NotAuthenticated:
            statusText = QStringLiteral("Not Authenticated");
            break;
        case QAbstractOAuth::Status::TemporaryCredentialsReceived:
            statusText = QStringLiteral("Temporary Credentials Received");
            break;
        case QAbstractOAuth::Status::Granted:
            statusText = QStringLiteral("Granted");
            break;
        case QAbstractOAuth::Status::RefreshingToken:
            statusText = QStringLiteral("Refreshing Token");
            break;
    }
    
    qDebug() << "🔐 OAuth status changed:" << statusText;
}

void OAuthManager::onTokenChanged(const QString &token)
{
    qDebug() << "🎫 Access token received (length:" << token.length() << ")";
    m_accessToken = token;
}

void OAuthManager::onGranted()
{
    qDebug() << "✅ OAuth2 grant successful, fetching user info";
    fetchUserInfo();
}

void OAuthManager::fetchUserInfo()
{
    if (m_accessToken.isEmpty()) {
        Q_EMIT authenticationFailed(QStringLiteral("No access token available"));
        return;
    }
    
    QNetworkRequest request{QUrl(GOOGLE_USERINFO_URL)};
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setRawHeader("Authorization", QStringLiteral("Bearer %1").arg(m_accessToken).toUtf8());
    
    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, &OAuthManager::onUserInfoReceived);
    
    qDebug() << "📡 Fetching user info from Google API";
}

void OAuthManager::onUserInfoReceived()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    
    if (!reply) {
        Q_EMIT authenticationFailed(QStringLiteral("Invalid reply object"));
        return;
    }
    
    if (reply->error() != QNetworkReply::NoError) {
        qDebug() << "❌ Failed to fetch user info:" << reply->errorString();
        Q_EMIT authenticationFailed(QStringLiteral("Failed to fetch user information: ") + reply->errorString());
        reply->deleteLater();
        return;
    }
    
    QByteArray data = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    QJsonObject userInfo = doc.object();
    
    m_userEmail = userInfo[QStringLiteral("email")].toString();
    m_userName = userInfo[QStringLiteral("name")].toString();
    m_isAuthenticated = true;
    
    qDebug() << "👤 User info received - Name:" << m_userName << "Email:" << m_userEmail;
    
    Q_EMIT authenticationChanged();
    Q_EMIT userInfoChanged();
    Q_EMIT authenticationSucceeded();
    
    reply->deleteLater();
}