import QtQuick 2.15
import QtQuick.Controls 2.15

TextField {
    id: dateField
    placeholderText: "ДД.ММ.ГГГГ"
    width: 120
    inputMask: "00.00.0000"
    font.pixelSize: 12
}
