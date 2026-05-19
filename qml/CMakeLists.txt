cmake_minimum_required(VERSION 3.21)
project(SurypusDashboard VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Charts Network)

qt_add_executable(surypus-dashboard
    main.cpp
    api/surypusapiclient.cpp
)

qt_add_qml_module(surypus-dashboard
    URI SurypusDashboard
    VERSION 1.0
    QML_FILES
        Main.qml
        components/Components.qml
)

target_link_libraries(surypus-dashboard PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Charts
    Qt6::Network
)
