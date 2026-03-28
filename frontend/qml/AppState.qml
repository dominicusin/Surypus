import QtQuick 2.15
import QtQml.Models 2.15

QtObject {
    id: appState

    // Properties for different entities
    property var persons: []
    property var goods: []
    property var inventory: []
    property var bills: []
    property var payroll: []
    property var reports: []
    property var settings: {}

    // Methods to update state
    function updatePersons(data) {
        persons = data;
    }

    function updateGoods(data) {
        goods = data;
    }

    function updateInventory(data) {
        inventory = data;
    }

    function updateBills(data) {
        bills = data;
    }

    function updatePayroll(data) {
        payroll = data;
    }

    function updateReports(data) {
        reports = data;
    }

    function updateSettings(data) {
        settings = data;
    }
}