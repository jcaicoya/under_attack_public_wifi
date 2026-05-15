#include <QApplication>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonParseError>
#include <QMessageBox>
#include <QScreen>
#include <QWidget>
#include "MainWindow.h"
#include "cybershow/common/CyberAppMode.h"
#include "cybershow/common/CyberOrchestratorProtocol.h"
#include "cybershow/common/CyberOperationalLog.h"
#include "cybershow/ui/CyberTheme.h"

static QString launchModeName(ShowConfig::LaunchMode mode)
{
    switch (mode) {
    case ShowConfig::LaunchMode::Demo:
        return QStringLiteral("demo");
    case ShowConfig::LaunchMode::Live:
        return QStringLiteral("live");
    }
    return QStringLiteral("demo");
}

// Returns an error description, or an empty string if everything is valid.
static QString validateResources()
{
    // ── Embedded Qt resources (compiled into the binary) ─────────────────────
    // These should never be missing, but we validate them so a bad build is
    // caught immediately rather than silently misbehaving at runtime.

    for (const QString& r : { QStringLiteral(":/world_map.svg"), QStringLiteral(":/flying-cuarzito.png") }) {
        QFile f(r);
        if (!f.open(QIODevice::ReadOnly) || f.size() == 0)
            return QString("Embedded resource is missing or empty: %1").arg(r);
    }

    {
        QFile f(":/demo_events.json");
        if (!f.open(QIODevice::ReadOnly))
            return "Cannot open embedded resource: demo_events.json";
        QJsonParseError e;
        QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &e);
        if (e.error != QJsonParseError::NoError)
            return QString("Corrupted embedded resource demo_events.json: %1").arg(e.errorString());
        if (!doc.isArray() || doc.array().isEmpty())
            return "demo_events.json must be a non-empty JSON array";
    }

    // ── Filesystem resources (read at runtime from resources/) ────────────────
    // These are under version control. Recover from GitHub if missing.

    auto findFile = [](const QString& name) -> QString {
        const QStringList candidates = {
            QDir::currentPath() + "/resources/" + name,
            QDir::cleanPath(QCoreApplication::applicationDirPath() + "/../resources/" + name),
            QDir::cleanPath(QCoreApplication::applicationDirPath() + "/../../resources/" + name),
            QCoreApplication::applicationDirPath() + "/" + name,
        };
        for (const QString& c : candidates)
            if (QFile::exists(c)) return c;
        return {};
    };

    // regions.json
    {
        QString path = findFile("regions.json");
        if (path.isEmpty())
            return "Required file not found: resources/regions.json\n\nRecover it from the GitHub repository.";
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly))
            return "Cannot open: " + path;
        QJsonParseError e;
        QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &e);
        if (e.error != QJsonParseError::NoError)
            return QString("Corrupted file regions.json: %1").arg(e.errorString());
        if (!doc.isObject() || doc.object()["regions"].toObject().isEmpty())
            return "regions.json is missing or has an empty 'regions' object";
    }

    // services.json
    {
        QString path = findFile("services.json");
        if (path.isEmpty())
            return "Required file not found: resources/services.json\n\nRecover it from the GitHub repository.";
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly))
            return "Cannot open: " + path;
        QJsonParseError e;
        QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &e);
        if (e.error != QJsonParseError::NoError)
            return QString("Corrupted file services.json: %1").arg(e.errorString());
        if (!doc.isObject() || doc.object().isEmpty())
            return "services.json must be a non-empty JSON object";
    }

    return {};
}

static ShowConfig configFromLaunchOptions(const cybershow::AppLaunchOptions& options)
{
    ShowConfig cfg;
    cfg.originalModeArgument = options.originalModeArgument;
    cfg.configPath = options.configPath;
    cfg.screenIndex = options.screenIndex;
    cfg.fullscreen = options.fullscreen;
    cfg.windowed = options.windowed;
    cfg.debug = options.debug;

    if (options.launchMode == cybershow::LaunchMode::Live) {
        cfg.launchMode = ShowConfig::LaunchMode::Live;
        cfg.mode = ShowConfig::Mode::Normal;
        cfg.profile = "live";
    } else {
        cfg.launchMode = ShowConfig::LaunchMode::Demo;
        cfg.mode = ShowConfig::Mode::Demo;
        cfg.profile = "demo";
    }

    return cfg;
}

static QRect availableGeometryForScreenIndex(int screenIndex)
{
    const auto screens = QGuiApplication::screens();
    if (screenIndex >= 0 && screenIndex < screens.size()) {
        return screens.at(screenIndex)->availableGeometry();
    }

    if (const QScreen* screen = QGuiApplication::primaryScreen()) {
        return screen->availableGeometry();
    }

    return {};
}

static double uiScaleForOptions(const cybershow::AppLaunchOptions& options)
{
    const auto screens = QGuiApplication::screens();
    const QScreen* screen = nullptr;
    if (options.screenIndex >= 0 && options.screenIndex < screens.size()) {
        screen = screens.at(options.screenIndex);
    } else {
        screen = QGuiApplication::primaryScreen();
    }

    if (!screen) {
        return 1.0;
    }

    const QRect available = screen->availableGeometry();
    const double scale = available.height() / 900.0;
    return qBound(0.85, scale, 1.15);
}

static void showMainWindow(MainWindow& window, const ShowConfig& config)
{
    const QRect available = availableGeometryForScreenIndex(config.screenIndex);
    if (config.fullscreen) {
        const auto screens = QGuiApplication::screens();
        if (config.screenIndex >= 0 && config.screenIndex < screens.size()) {
            window.move(screens.at(config.screenIndex)->geometry().topLeft());
        }
        window.showFullScreen();
    } else if (config.windowed) {
        if (!available.isEmpty()) {
            const QSize targetSize(
                qBound(1280, int(available.width() * 0.90), 1680),
                qBound(720, int(available.height() * 0.90), 1080));
            const QRect targetRect(
                QPoint(
                    available.x() + (available.width() - targetSize.width()) / 2,
                    available.y() + (available.height() - targetSize.height()) / 2),
                targetSize);
            window.setGeometry(targetRect.intersected(available));
        } else {
            window.resize(1280, 720);
        }
        window.show();
    } else {
        const auto screens = QGuiApplication::screens();
        if (config.screenIndex >= 0 && config.screenIndex < screens.size()) {
            window.move(screens.at(config.screenIndex)->geometry().topLeft());
        } else if (!available.isEmpty()) {
            window.move(available.topLeft());
        }
        window.showFullScreen();
    }
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("under_attack_public_wifi"));
    cybershow::OperationalLog::configure(QStringLiteral("startup"), QStringLiteral("unknown"));
    cybershow::OperationalLog::write(QStringLiteral("INFO"), QStringLiteral("startup"), QStringLiteral("Application process started"));

    QStringList args = QCoreApplication::arguments();
    for (auto& a : args) {
        if (a == "--show")   a = "--live";
        if (a == "--design") a = "--demo";
    }
    const cybershow::ParseResult launchParse =
        cybershow::parseAppLaunchOptions(args);
    if (!launchParse.ok) {
        cybershow::OrchestratorProtocol::status("ERROR", "INVALID_ARGUMENTS");
        cybershow::OperationalLog::write(QStringLiteral("ERROR"), QStringLiteral("startup"), QStringLiteral("Invalid launch arguments"));
        QMessageBox::critical(
            nullptr,
            "Public Wi-Fi Cybershow - Startup Error",
            "The application cannot start because the launch arguments are invalid.\n\n"
            + launchParse.error
        );
        return 2;
    }

    const QString resourceError = validateResources();
    if (!resourceError.isEmpty()) {
        cybershow::OrchestratorProtocol::status("ERROR", "RESOURCE_VALIDATION");
        cybershow::OperationalLog::write(QStringLiteral("ERROR"), QStringLiteral("startup"), QStringLiteral("Resource validation failed"));
        QMessageBox::critical(
            nullptr,
            "Public Wi-Fi Cybershow — Resource Error",
            "The application cannot start because a required resource file is missing or corrupted.\n\n"
            + resourceError
        );
        return 1;
    }

    cybershow::OrchestratorProtocol::status("READY");
    cybershow::OperationalLog::write(QStringLiteral("INFO"), QStringLiteral("startup"), QStringLiteral("Application ready"));

    const double uiScale = uiScaleForOptions(launchParse.options);
    app.setStyle("Fusion");
    app.setStyleSheet(CyberTheme::globalStyleSheet(uiScale));

    ShowConfig config = configFromLaunchOptions(launchParse.options);

    cybershow::OperationalLog::configure(launchModeName(config.launchMode), config.profile);
    cybershow::OperationalLog::write(QStringLiteral("INFO"), QStringLiteral("runtime"), QStringLiteral("Creating runtime window"));

    MainWindow window(config);
    showMainWindow(window, config);
    cybershow::OrchestratorProtocol::status("RUNNING");
    cybershow::OperationalLog::write(QStringLiteral("INFO"), QStringLiteral("runtime"), QStringLiteral("Runtime window shown"));

    const int result = app.exec();
    cybershow::OperationalLog::write(QStringLiteral("INFO"), QStringLiteral("runtime"), QString("Application exited with code %1").arg(result));
    return result;
}
