.pragma library
.import QtQuick.LocalStorage 2.0 as Sql
.import "examples.js" as Examples

// The projects: one Structured Text source each, in one SQLite database
// in the app's data directory (allowed by Sailjail). On the first start
// it gets the example projects; deleted ones don't come back.

var db = null

function open() {
    if (db) return db
    db = Sql.LocalStorage.openDatabaseSync("CodeSysFish", "", "CodeSysFish projects", 20000000)
    db.transaction(function(tx) {
        tx.executeSql("CREATE TABLE IF NOT EXISTS projects (id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                      "name TEXT, description TEXT, source TEXT, modified REAL)")
        tx.executeSql("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
        var seeded = tx.executeSql("SELECT value FROM settings WHERE key = 'seeded'")
        if (seeded.rows.length === 0) {
            var now = Date.now()
            for (var i = 0; i < Examples.projects.length; i++) {
                var ex = Examples.projects[i]
                // Oldest first, so the list (newest first) starts with the first example.
                tx.executeSql("INSERT INTO projects (name, description, source, modified) VALUES (?, ?, ?, ?)",
                              [ex.name, ex.description, ex.source, now - i * 1000])
            }
            tx.executeSql("INSERT INTO settings (key, value) VALUES ('seeded', '1')")
        }
    })
    return db
}

// [{ id, name, description, modified }], most recently changed first.
function list() {
    var out = []
    open().readTransaction(function(tx) {
        var rs = tx.executeSql("SELECT id, name, description, modified FROM projects ORDER BY modified DESC")
        for (var i = 0; i < rs.rows.length; i++) {
            var r = rs.rows.item(i)
            out.push({ id: r.id, name: r.name, description: r.description || "", modified: r.modified })
        }
    })
    return out
}

function get(id) {
    var out = null
    open().readTransaction(function(tx) {
        var rs = tx.executeSql("SELECT id, name, description, source, modified FROM projects WHERE id = ?", [id])
        if (rs.rows.length > 0) {
            var r = rs.rows.item(0)
            out = { id: r.id, name: r.name, description: r.description || "", source: r.source, modified: r.modified }
        }
    })
    return out
}

// The new project's id.
function create(name, source, description) {
    var id = -1
    open().transaction(function(tx) {
        var rs = tx.executeSql("INSERT INTO projects (name, description, source, modified) VALUES (?, ?, ?, ?)",
                               [name, description || "", source, Date.now()])
        id = parseInt(rs.insertId, 10)
    })
    return id
}

function save(id, source) {
    open().transaction(function(tx) {
        tx.executeSql("UPDATE projects SET source = ?, modified = ? WHERE id = ?", [source, Date.now(), id])
    })
}

function rename(id, name) {
    open().transaction(function(tx) {
        tx.executeSql("UPDATE projects SET name = ?, modified = ? WHERE id = ?", [name, Date.now(), id])
    })
}

function remove(id) {
    open().transaction(function(tx) {
        tx.executeSql("DELETE FROM projects WHERE id = ?", [id])
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

// A name not yet used: "Name", "Name 2", ...
function freeName(name) {
    var names = list().map(function(p) { return p.name.toLowerCase() })
    if (names.indexOf(name.toLowerCase()) < 0) return name
    for (var i = 2; ; i++) {
        if (names.indexOf((name + " " + i).toLowerCase()) < 0) return name + " " + i
    }
}
