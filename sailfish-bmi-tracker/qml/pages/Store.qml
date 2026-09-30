import QtQuick 2.0
import "../js/storage.js" as Storage
import "../js/bmi.js" as Bmi

// The app's data, loaded from and saved straight to the database, shared
// by every page and the cover.
QtObject {
    id: store

    // Profile
    property string gender: ""        // "female", "male", "other" or ""
    property int age: 0               // 0 = not given
    property real heightCm: 0         // 0 = not given
    property string weightUnit: "kg"  // "kg" or "lb"
    property string heightUnit: "cm"  // "cm" or "ftin"

    // [{ id, date: "yyyy-mm-dd", weightKg, bmi }], oldest first
    property var entries: []

    readonly property bool hasProfile: heightCm > 0
    readonly property var latest: entries.length > 0 ? entries[entries.length - 1] : null
    readonly property real currentBmi: latest ? latest.bmi : NaN
    readonly property var currentCategory: Bmi.category(currentBmi)

    function load() {
        var p = Storage.profile()
        gender = p.gender || ""
        age = parseInt(p.age || "0", 10) || 0
        heightCm = parseFloat(p.heightCm || "0") || 0
        weightUnit = p.weightUnit === "lb" ? "lb" : "kg"
        heightUnit = p.heightUnit === "ftin" ? "ftin" : "cm"
        loadEntries()
    }

    function loadEntries() {
        var list = Storage.entries()
        for (var i = 0; i < list.length; i++) {
            list[i].bmi = Bmi.bmi(list[i].weightKg, heightCm)
        }
        entries = list
    }

    function saveProfile(values) {
        Storage.setProfile(values)
        load() // BMI of every entry depends on the height
    }

    function addEntry(date, weightKg) {
        Storage.addEntry(date, weightKg)
        loadEntries()
    }

    function removeEntry(id) {
        Storage.removeEntry(id)
        loadEntries()
    }

    // "yyyy-mm-dd" for a Date, in local time.
    function isoDate(d) {
        function pad(n) { return (n < 10 ? "0" : "") + n }
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
    }

    function parseIsoDate(s) {
        var p = s.split("-")
        return new Date(parseInt(p[0], 10), parseInt(p[1], 10) - 1, parseInt(p[2], 10))
    }

    Component.onCompleted: load()
}
