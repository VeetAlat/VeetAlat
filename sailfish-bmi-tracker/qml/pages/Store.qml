import QtQuick 2.0
import "../js/storage.js" as Storage
import "../js/bmi.js" as Bmi

// The app's data, loaded from and saved straight to the database, shared
// by every page and the cover. There is exactly one, created in the main
// QML file as "appStore" and handed to each page.
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

    // Set when reading or writing the database fails, shown on the main
    // page so a problem is never silent. Empty when all is well.
    property string lastError: ""

    // True once the saved data has been read.
    property bool loaded: false

    readonly property bool hasProfile: heightCm > 0
    readonly property var latest: entries.length > 0 ? entries[entries.length - 1] : null
    readonly property real currentBmi: latest ? latest.bmi : NaN
    readonly property var currentCategory: Bmi.category(currentBmi)

    function fail(what, e) {
        lastError = what + ": " + (e && e.message ? e.message : e)
        console.warn("BMI Tracker:", lastError)
        return false
    }

    function load() {
        try {
            var p = Storage.profile()
            gender = p.gender || ""
            age = parseInt(p.age || "0", 10) || 0
            heightCm = parseFloat(p.heightCm || "0") || 0
            weightUnit = p.weightUnit === "lb" ? "lb" : "kg"
            heightUnit = p.heightUnit === "ftin" ? "ftin" : "cm"
            loadEntries()
            loaded = true
            return true
        } catch (e) {
            return fail("Could not read saved data", e)
        }
    }

    function loadEntries() {
        var list = Storage.entries()
        for (var i = 0; i < list.length; i++) {
            list[i].bmi = Bmi.bmi(list[i].weightKg, heightCm)
        }
        entries = list
    }

    // Returns true when saved.
    function saveProfile(values) {
        try {
            Storage.setProfile(values)
        } catch (e) {
            return fail("Could not save your profile", e)
        }
        lastError = ""
        return load() // every entry's BMI depends on the height
    }

    function addEntry(date, weightKg) {
        try {
            Storage.addEntry(date, weightKg)
            loadEntries()
        } catch (e) {
            return fail("Could not save the weight", e)
        }
        lastError = ""
        return true
    }

    function removeEntry(id) {
        try {
            Storage.removeEntry(id)
            loadEntries()
        } catch (e) {
            return fail("Could not delete the measurement", e)
        }
        return true
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
