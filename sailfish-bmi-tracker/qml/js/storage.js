.pragma library
.import QtQuick.LocalStorage 2.0 as Sql

// Everything the app remembers lives in one SQLite database in the app's
// data directory (~/.local/share/org.veetalat/bmitracker/), which Sailjail
// lets the app write without any extra permission.
//
//   profile(key, value)       gender, age, heightCm, weightUnit, heightUnit
//   entries(id, date, weightKg)  date as "yyyy-mm-dd"

var db = null

function open() {
    if (db) return db
    db = Sql.LocalStorage.openDatabaseSync("BmiTracker", "", "BMI Tracker data", 100000)
    db.transaction(function(tx) {
        tx.executeSql("CREATE TABLE IF NOT EXISTS profile (key TEXT PRIMARY KEY, value TEXT)")
        tx.executeSql("CREATE TABLE IF NOT EXISTS entries (id INTEGER PRIMARY KEY AUTOINCREMENT, "
                      + "date TEXT NOT NULL, weightKg REAL NOT NULL)")
    })
    return db
}

function profile() {
    var result = {}
    open().readTransaction(function(tx) {
        var rs = tx.executeSql("SELECT key, value FROM profile")
        for (var i = 0; i < rs.rows.length; i++) {
            result[rs.rows.item(i).key] = rs.rows.item(i).value
        }
    })
    return result
}

function setProfile(values) {
    open().transaction(function(tx) {
        for (var key in values) {
            tx.executeSql("INSERT OR REPLACE INTO profile (key, value) VALUES (?, ?)",
                          [key, String(values[key])])
        }
    })
}

// Oldest first.
function entries() {
    var result = []
    open().readTransaction(function(tx) {
        var rs = tx.executeSql("SELECT id, date, weightKg FROM entries ORDER BY date, id")
        for (var i = 0; i < rs.rows.length; i++) {
            var r = rs.rows.item(i)
            result.push({ id: r.id, date: r.date, weightKg: r.weightKg })
        }
    })
    return result
}

function addEntry(date, weightKg) {
    open().transaction(function(tx) {
        tx.executeSql("INSERT INTO entries (date, weightKg) VALUES (?, ?)", [date, weightKg])
    })
}

function removeEntry(id) {
    open().transaction(function(tx) {
        tx.executeSql("DELETE FROM entries WHERE id = ?", [id])
    })
}
