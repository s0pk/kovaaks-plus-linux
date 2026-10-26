#include <QCommandLineParser>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QtQml/qqml.h>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QtGlobal>

#include "launch.h"

int main(int argc, char *argv[])
{
    // Scene graph back end: KPLUS_GPU_API=vulkan|opengl|software (default: Qt's choice for the platform).
    const QByteArray api = qgetenv("KPLUS_GPU_API").toLower();
    if (api == "vulkan") QQuickWindow::setGraphicsApi(QSGRendererInterface::Vulkan);
    else if (api == "opengl" || api == "gl") QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
    else if (api == "software") QQuickWindow::setGraphicsApi(QSGRendererInterface::Software);

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("kovaaks-plus");
    QGuiApplication::setApplicationDisplayName("Kovaak's Plus");
    QGuiApplication::setDesktopFileName("kovaaks-plus");
    QGuiApplication::setWindowIcon(QIcon(":/qt/qml/Kplus/assets/logo.png"));
    QQuickStyle::setStyle("Basic");

    QCommandLineParser parser;
    QCommandLineOption ws("ws", "Backend WebSocket URL", "url");
    QCommandLineOption http("http", "Backend HTTP base URL", "url");
    QCommandLineOption dev("dev", "Developer mode");
    parser.addOptions({ws, http, dev});
    parser.process(app);
    Launch::instance()->ws = parser.value(ws);
    Launch::instance()->http = parser.value(http);
    Launch::instance()->dev = parser.isSet(dev);

    qmlRegisterSingletonInstance("Kplus", 1, 0, "Launch", Launch::instance());
    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("Kplus", "Main");
    return app.exec();
}
