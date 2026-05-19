#ifndef SURYPUSAPICLIENT_H
#define SURYPUSAPICLIENT_H

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QUrlQuery>

/// SurypusApiClient — QML-accessible C++ wrapper for REST API calls.
///
/// Uses Qt's QNetworkAccessManager for all HTTP communication with the
/// Surypus backend. JWT token is stored in memory and injected as
/// Authorization: Bearer header on all authenticated requests.
///
/// Usage from QML:
///   ApiClient.login(username, password)
///   ApiClient.get("/bills")
///   ApiClient.post("/bills", { "field": "value" })
class SurypusApiClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString baseUrl READ baseUrl WRITE setBaseUrl NOTIFY baseUrlChanged)
    Q_PROPERTY(QString authToken READ authToken NOTIFY authTokenChanged)

public:
    explicit SurypusApiClient(QObject *parent = nullptr);
    ~SurypusApiClient() override = default;

    /// Base URL getter/setter
    QString baseUrl() const { return m_baseUrl; }
    void setBaseUrl(const QString &url);

    /// Current JWT auth token
    QString authToken() const { return m_authToken; }

    // ── QML-invokable methods ──────────────────────────────────────────────────

    /// POST to /login with username+password, stores returned JWT
    Q_INVOKABLE void login(const QString &username, const QString &password);

    /// GET request to <baseUrl>/<path>
    Q_INVOKABLE void get(const QString &path);

    /// POST request to <baseUrl>/<path> with JSON body
    Q_INVOKABLE void post(const QString &path, const QJsonObject &body);

    /// PUT request to <baseUrl>/<path> with JSON body
    Q_INVOKABLE void put(const QString &path, const QJsonObject &body);

    /// DELETE request to <baseUrl>/<path>
    Q_INVOKABLE void del(const QString &path);

    /// Clear stored auth token (logout)
    Q_INVOKABLE void logout();

signals:
    void baseUrlChanged();
    void authTokenChanged();

    // ── Response signals ────────────────────────────────────────────────────────
    void loginSucceeded(const QString &token);
    void loginFailed(const QString &error);

    void requestSucceeded(const QString &path, const QJsonDocument &response);
    void requestFailed(const QString &path, int statusCode, const QString &error);

private:
    QNetworkAccessManager *m_manager = nullptr;
    QString m_baseUrl;
    QString m_authToken;

    /// Build the full URL for a given API path
    QUrl buildUrl(const QString &path) const;

    /// Make an authenticated (or anonymous) request
    QNetworkReply* makeRequest(const QString &method,
                               const QString &path,
                               const QByteArray &body = QByteArray());

    /// Handle a network reply and emit appropriate signals
    void handleReply(QNetworkReply *reply, const QString &path);
};

#endif // SURYPUSAPICLIENT_H
