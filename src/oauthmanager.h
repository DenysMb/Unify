#ifndef OAUTHMANAGER_H
#define OAUTHMANAGER_H

#include <QNetworkAccessManager>
#include <QOAuth2AuthorizationCodeFlow>
#include <QOAuthHttpServerReplyHandler>
#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantMap>

class OAuthManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isAuthenticated READ isAuthenticated NOTIFY authenticationChanged)
    Q_PROPERTY(QString userEmail READ userEmail NOTIFY userInfoChanged)
    Q_PROPERTY(QString userName READ userName NOTIFY userInfoChanged)

public:
    explicit OAuthManager(QObject *parent = nullptr);

    bool isAuthenticated() const;
    QString userEmail() const;
    QString userName() const;

    Q_INVOKABLE void authenticateWithGoogle();
    Q_INVOKABLE void logout();

Q_SIGNALS:
    void authenticationChanged();
    void userInfoChanged();
    void authenticationSucceeded();
    void authenticationFailed(const QString &error);

private Q_SLOTS:
    void onStatusChanged(QAbstractOAuth::Status status);
    void onTokenChanged(const QString &token);
    void onGranted();
    void fetchUserInfo();
    void onUserInfoReceived();

private:
    void setupGoogleOAuth();

    QOAuth2AuthorizationCodeFlow *m_googleFlow;
    QOAuthHttpServerReplyHandler *m_replyHandler;
    QNetworkAccessManager *m_networkManager;

    bool m_isAuthenticated;
    QString m_userEmail;
    QString m_userName;
    QString m_accessToken;

    // Google OAuth2 configuration
    static const QString GOOGLE_CLIENT_ID;
    static const QString GOOGLE_CLIENT_SECRET;
    static const QString GOOGLE_AUTH_URL;
    static const QString GOOGLE_TOKEN_URL;
    static const QString GOOGLE_USERINFO_URL;
    static const QString GOOGLE_SCOPE;
};

#endif // OAUTHMANAGER_H
