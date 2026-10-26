#pragma once
#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>
#include <QQmlEngine>
#include <QJSEngine>

// Start-up information from the backend (the C# process that spawned us), visible to QML as the `Launch` singleton.
class Launch : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString ws MEMBER ws CONSTANT)       // ws://127.0.0.1:PORT/ws?t=TOKEN
    Q_PROPERTY(QString http MEMBER http CONSTANT)   // http://127.0.0.1:PORT  (media and crosshair images)
    Q_PROPERTY(bool dev MEMBER dev CONSTANT)
public:
    explicit Launch(QObject *parent = nullptr) : QObject(parent) {}
    static Launch *instance();
    QString ws, http;
    bool dev = false;
};
