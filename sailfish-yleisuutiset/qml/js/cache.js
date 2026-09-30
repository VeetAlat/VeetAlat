.pragma library
.import QtQuick.LocalStorage 2.0 as Sql

// Last fetched feed per category, plus small settings, in one SQLite
// database in the app's data directory (allowed by Sailjail). Lets the app
// show news immediately on start and when offline.

var db = null

function open() {
    if (db) return db
    db = Sql.LocalStorage.openDatabaseSync("Yleisuutiset", "", "Yleisuutiset cache", 5000000)
    db.transaction(function(tx) {
        tx.executeSql("CREATE TABLE IF NOT EXISTS feeds (key TEXT PRIMARY KEY, fetched REAL, json TEXT)")
        tx.executeSql("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
    })
    return db
}

// { fetched: ms, items: [...] } or null
function feed(key) {
    var result = null
    open().readTransaction(function(tx) {
        var rs = tx.executeSql("SELECT fetched, json FROM feeds WHERE key = ?", [key])
        if (rs.rows.length > 0) {
            try {
                result = { fetched: rs.rows.item(0).fetched, items: JSON.parse(rs.rows.item(0).json) }
            } catch (e) {
                result = null // a broken cache entry is just a cache miss
            }
        }
    })
    return result
}

function saveFeed(key, fetched, items) {
    open().transaction(function(tx) {
        tx.executeSql("INSERT OR REPLACE INTO feeds (key, fetched, json) VALUES (?, ?, ?)",
                      [key, fetched, JSON.stringify(items)])
    })
}

function setting(key, fallback) {
    var value = fallback
    open().readTransaction(function(tx) {
        var rs = tx.executeSql("SELECT value FROM settings WHERE key = ?", [key])
        if (rs.rows.length > 0) value = rs.rows.item(0).value
    })
    return value
}

function setSetting(key, value) {
    open().transaction(function(tx) {
        tx.executeSql("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", [key, String(value)])
    })
}
