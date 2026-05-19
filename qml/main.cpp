#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "api/surypusapiclient.h"

static QObject *apiClientSingleton(QQmlEngine *engine, QJSEngine *)
{
    return new SurypusApiClient(engine);
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QQmlApplicationEngine engine;

    // Register ApiClient as a QML singleton — available to all QML files
    qmlRegisterSingletonType<SurypusApiClient>(
        "SurypusApiClient", 1, 0, "ApiClient", apiClientSingleton);

    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/SurypusDashboard/Main.qml")));
    return app.exec();
}
