#include "surypusapiclient.h"
#include <QJsonDocument>
#include <QJsonParseError>

SurypusApiClient::SurypusApiClient(QObject *parent)
    : QObject(parent)
    , m_manager(new QNetworkAccessManager(this))
    , m_baseUrl("http://localhost:3000/api/v1")
{
}

void SurypusApiClient::setBaseUrl(const QString &url)
{
    if (m_baseUrl != url) {
        m_baseUrl = url;
        emit baseUrlChanged();
    }
}

QUrl SurypusApiClient::buildUrl(const QString &path) const
{
    // Path should start with / — e.g. /bills, /login
    QString fullPath = path.startsWith('/') ? path : '/' + path;
    return QUrl(m_baseUrl + fullPath);
}

QNetworkReply* SurypusApiClient::makeRequest(const QString &method,
                                              const QString &path,
                                              const QByteArray &body)
{
    QUrl url = buildUrl(path);
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    // Inject auth token for authenticated requests
    if (!m_authToken.isEmpty()) {
        request.setRawHeader("Authorization",
                             QString("Bearer %1").arg(m_authToken).toUtf8());
    }

    if (method == "GET") {
        return m_manager->get(request);
    } else if (method == "POST") {
        return m_manager->post(request, body);
    } else if (method == "PUT") {
        return m_manager->put(request, body);
    } else if (method == "DELETE") {
        return m_manager->deleteResource(request);
    }
    return nullptr;
}

void SurypusApiClient::handleReply(QNetworkReply *reply, const QString &path)
{
    connect(reply, &QNetworkReply::finished, this, [this, reply, path]() {
        reply->deleteLater();

        int statusCode = reply->attribute(
            QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QByteArray data = reply->readAll();

        if (reply->error() == QNetworkReply::NoError) {
            QJsonParseError parseError;
            QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
            if (parseError.error == QJsonParseError::NoError) {
                emit requestSucceeded(path, doc);
            } else {
                // Return raw text as a string value when JSON parsing fails
                QJsonObject fallback;
                fallback["raw"] = QString::fromUtf8(data);
                emit requestSucceeded(path, QJsonDocument(fallback));
            }
        } else {
            QString errorMsg = reply->errorString();
            if (!data.isEmpty()) {
                // Try to extract error from JSON response
                QJsonParseError parseError;
                QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
                if (parseError.error == QJsonParseError::NoError &&
                    doc.isObject() && doc.object().contains("error")) {
                    errorMsg = doc.object()["error"].toString();
                }
            }
            emit requestFailed(path, statusCode, errorMsg);
        }
    });
}

void SurypusApiClient::login(const QString &username, const QString &password)
{
    QJsonObject body;
    body["lrUsername"] = username;
    body["lrPassword"] = password;

    QByteArray jsonBody = QJsonDocument(body).toJson(QJsonDocument::Compact);
    QNetworkReply *reply = makeRequest("POST", "/login", jsonBody);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        int statusCode = reply->attribute(
            QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QByteArray data = reply->readAll();

        if (statusCode == 200 && reply->error() == QNetworkReply::NoError) {
            QJsonDocument doc = QJsonDocument::fromJson(data);
            if (doc.isObject()) {
                QJsonObject obj = doc.object();
                if (obj.contains("lrToken")) {
                    m_authToken = obj["lrToken"].toString();
                    emit authTokenChanged();
                    emit loginSucceeded(m_authToken);
                    return;
                }
            }
        }

        // Login failed — extract error message
        QString errorMsg = reply->errorString();
        if (!data.isEmpty()) {
            QJsonDocument doc = QJsonDocument::fromJson(data);
            if (doc.isObject() && doc.object().contains("error")) {
                errorMsg = doc.object()["error"].toString();
            }
        }
        emit loginFailed(errorMsg);
    });
}

void SurypusApiClient::get(const QString &path)
{
    QNetworkReply *reply = makeRequest("GET", path);
    handleReply(reply, path);
}

void SurypusApiClient::post(const QString &path, const QJsonObject &body)
{
    QByteArray jsonBody = QJsonDocument(body).toJson(QJsonDocument::Compact);
    QNetworkReply *reply = makeRequest("POST", path, jsonBody);
    handleReply(reply, path);
}

void SurypusApiClient::put(const QString &path, const QJsonObject &body)
{
    QByteArray jsonBody = QJsonDocument(body).toJson(QJsonDocument::Compact);
    QNetworkReply *reply = makeRequest("PUT", path, jsonBody);
    handleReply(reply, path);
}

void SurypusApiClient::del(const QString &path)
{
    QNetworkReply *reply = makeRequest("DELETE", path);
    handleReply(reply, path);
}

void SurypusApiClient::logout()
{
    if (!m_authToken.isEmpty()) {
        m_authToken.clear();
        emit authTokenChanged();
    }
}
