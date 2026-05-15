#include "CyberOperationalLog.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMutex>
#include <QMutexLocker>
#include <QTextStream>

namespace cybershow {
namespace {

QMutex& logMutex()
{
    static QMutex mutex;
    return mutex;
}

QString& launchModeField()
{
    static QString value = QStringLiteral("unknown");
    return value;
}

QString& profileField()
{
    static QString value = QStringLiteral("unknown");
    return value;
}

QString sanitize(QString value)
{
    value.replace('\n', ' ');
    value.replace('\r', ' ');
    value.replace('|', '/');
    return value.trimmed();
}

} // namespace

void OperationalLog::configure(const QString& launchMode, const QString& profile)
{
    QMutexLocker locker(&logMutex());
    launchModeField() = sanitize(launchMode);
    profileField() = sanitize(profile);
}

QString OperationalLog::filePath()
{
    const QString basePath = QCoreApplication::applicationDirPath().isEmpty()
        ? QDir::currentPath()
        : QCoreApplication::applicationDirPath();
    return QDir(basePath).filePath(QStringLiteral("logs/under_attack_public_wifi.log"));
}

void OperationalLog::write(const QString& level, const QString& component, const QString& message)
{
    QMutexLocker locker(&logMutex());

    QFileInfo info(filePath());
    QDir().mkpath(info.absolutePath());

    QFile file(info.absoluteFilePath());
    if (!file.open(QIODevice::Append | QIODevice::Text)) {
        return;
    }

    QTextStream out(&file);
    out << QDateTime::currentDateTimeUtc().toString(Qt::ISODate)
        << " | under_attack_public_wifi | "
        << sanitize(launchModeField())
        << " | "
        << sanitize(profileField())
        << " | "
        << sanitize(level)
        << " | "
        << sanitize(component)
        << " | "
        << sanitize(message)
        << Qt::endl;
}

} // namespace cybershow
