cmake_minimum_required(VERSION 3.21)
project(kovaaks-plus-ui LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 WebSockets Svg Multimedia)
qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)

# QML singletons must be flagged before the module is created.
set_source_files_properties(
    qml/Theme.qml qml/Backend.qml qml/Store.qml qml/Modals.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_executable(kovaaks-plus-ui main.cpp)

file(GLOB QML_SOURCES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS qml/*.qml)
file(GLOB JS_SOURCES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS qml/js/*.js)
file(GLOB ASSET_FILES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS assets/*)

qt_add_qml_module(kovaaks-plus-ui
    URI Kplus
    VERSION 1.0
    SOURCES launch.h launch.cpp
    QML_FILES ${QML_SOURCES}
    RESOURCES ${JS_SOURCES} ${ASSET_FILES}
)

target_link_libraries(kovaaks-plus-ui PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::WebSockets Qt6::Svg Qt6::Multimedia)
install(TARGETS kovaaks-plus-ui RUNTIME DESTINATION bin)
