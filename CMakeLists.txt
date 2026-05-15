cmake_minimum_required(VERSION 3.28)
project(under_attack_public_wifi)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

set(CMAKE_PREFIX_PATH "C:/Qt/6.7.3/msvc2022_64")

find_package(Qt6 COMPONENTS
        Core
        Gui
        Multimedia
        Network
        Widgets
        Svg
        REQUIRED)

add_executable(under_attack_public_wifi
        src/main.cpp
        src/ShowConfig.h
        src/cybershow/common/CyberAppMode.h
        src/cybershow/common/CyberAppMode.cpp
        src/cybershow/common/CyberNavigationController.h
        src/cybershow/common/CyberNavigationController.cpp
        src/cybershow/common/CyberOrchestratorProtocol.h
        src/cybershow/common/CyberOperationalLog.h
        src/cybershow/common/CyberOperationalLog.cpp
        src/cybershow/common/ScreenDefinition.h
        src/cybershow/ui/AlertBanner.h
        src/cybershow/ui/AlertBanner.cpp
        src/cybershow/ui/BottomNavBar.h
        src/cybershow/ui/BottomNavBar.cpp
        src/cybershow/ui/CyberBackgroundWidget.h
        src/cybershow/ui/CyberBackgroundWidget.cpp
        src/cybershow/ui/CyberPanel.h
        src/cybershow/ui/CyberPanel.cpp
        src/cybershow/ui/CyberTheme.h
        src/cybershow/ui/CyberTheme.cpp
        src/cybershow/ui/MetricCard.h
        src/cybershow/ui/MetricCard.cpp
        src/TcpJsonLineServer.cpp
        src/TcpJsonLineServer.h
        src/WifiPortalServer.h
        src/WifiPortalServer.cpp
        src/MainWindow.cpp
        src/MainWindow.h
        src/ScreenPage.cpp
        src/ScreenPage.h
        src/MapView.cpp
        src/MapView.h
        resources/resources.qrc)

target_link_libraries(under_attack_public_wifi
        Qt::Core
        Qt::Gui
        Qt::Multimedia
        Qt::Network
        Qt::Widgets
        Qt::Svg
)

target_include_directories(under_attack_public_wifi PRIVATE
        src/cybershow/common
        src/cybershow/ui
)

# Hide the console window in Release builds; keep it in Debug so CLion can stop the process.
if(WIN32)
    set_target_properties(under_attack_public_wifi PROPERTIES
        WIN32_EXECUTABLE "$<CONFIG:Release,RelWithDebInfo>")
endif()

add_subdirectory(tools/polygon-editor)
add_subdirectory(tools/service-mapper)

if (WIN32 AND NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    set(DEBUG_SUFFIX)
    if (MSVC AND CMAKE_BUILD_TYPE MATCHES "Debug")
        set(DEBUG_SUFFIX "d")
    endif ()
    set(QT_INSTALL_PATH "${CMAKE_PREFIX_PATH}")
    if (NOT EXISTS "${QT_INSTALL_PATH}/bin")
        set(QT_INSTALL_PATH "${QT_INSTALL_PATH}/..")
        if (NOT EXISTS "${QT_INSTALL_PATH}/bin")
            set(QT_INSTALL_PATH "${QT_INSTALL_PATH}/..")
        endif ()
    endif ()
    if (EXISTS "${QT_INSTALL_PATH}/plugins/platforms/qwindows${DEBUG_SUFFIX}.dll")
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E make_directory
                "$<TARGET_FILE_DIR:${PROJECT_NAME}>/plugins/platforms/")
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy
                "${QT_INSTALL_PATH}/plugins/platforms/qwindows${DEBUG_SUFFIX}.dll"
                "$<TARGET_FILE_DIR:${PROJECT_NAME}>/plugins/platforms/")
    endif ()
    if (EXISTS "${QT_INSTALL_PATH}/plugins/multimedia/windowsmediaplugin${DEBUG_SUFFIX}.dll")
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E make_directory
                "$<TARGET_FILE_DIR:${PROJECT_NAME}>/plugins/multimedia/")
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy
                "${QT_INSTALL_PATH}/plugins/multimedia/windowsmediaplugin${DEBUG_SUFFIX}.dll"
                "$<TARGET_FILE_DIR:${PROJECT_NAME}>/plugins/multimedia/")
    endif ()
    foreach (QT_LIB Core Gui Multimedia Network Widgets Svg)
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy
                "${QT_INSTALL_PATH}/bin/Qt6${QT_LIB}${DEBUG_SUFFIX}.dll"
                "$<TARGET_FILE_DIR:${PROJECT_NAME}>")
    endforeach (QT_LIB)
endif ()
