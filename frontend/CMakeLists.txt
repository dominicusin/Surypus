cmake_minimum_required(VERSION 3.16)
project(SurypusFrontend LANGUAGES CXX)

# Qt6 configuration
find_package(Qt6 COMPONENTS Core Qml Quick REQUIRED)

# Set the C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add the QML files
qt6_add_resources(SURYPUS_QML
    "qml"
    PREFIX "/"
    FILES
        qml/Main.qml
        qml/AppState.qml
        qml/RestClient.qml
        qml/WsClient.qml
        qml/components/Components.qml
        qml/screens/Persons.qml
        qml/screens/Goods.qml
        qml/screens/Accounting.qml
        qml/screens/Payroll.qml
        qml/screens/Reports.qml
        qml/screens/Settings.qml
)

# Create the executable
add_executable(surypus-frontend
    main.cpp
    ${SURYPUS_QML}
)

# Link Qt libraries
target_link_libraries(surypus-frontend
    PRIVATE
        Qt6::Core
        Qt6::Qml
        Qt6::Quick
)

# Install the executable
install(TARGETS surypus-frontend
    RUNTIME DESTINATION bin
)