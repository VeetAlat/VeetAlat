import QtQuick 2.0
import "js/bmi.js" as Bmi

// Injected into a copy of the app by tests/sdk-smoke-test.sh (never
// shipped). Drives the real pages the way the UI does, then checks the
// data survives a restart: run 1 fills everything in, run 2 checks it.
//
// Property names differ from anything the app uses on purpose, so a
// binding like "testedStore: appStore" can't shadow itself.
QtObject {
    id: smoke

    property var testedWindow
    property var testedStore
    property int failures: 0

    function check(name, ok) {
        console.log((ok ? "SMOKE PASS " : "SMOKE FAIL ") + name)
        if (!ok) failures++
    }

    function make(url, props) {
        var c = Qt.createComponent(Qt.resolvedUrl(url))
        if (c.status !== Component.Ready) {
            check("load " + url + ": " + c.errorString(), false)
            return null
        }
        return c.createObject(testedWindow, props)
    }

    function noNaN(name, s) {
        check(name + " shows no NaN ('" + s + "')", String(s).toLowerCase().indexOf("nan") < 0)
    }

    Component.onCompleted: {
        // This object and the store are siblings, and Qt doesn't promise
        // which finishes starting first. The app itself only builds pages
        // after start-up, when the store has loaded; do the same here.
        if (!testedStore.loaded) testedStore.load()
        check("saved data loads", testedStore.loaded)

        // Exactly how the app builds its first page and its cover.
        var page = testedWindow.initialPage.createObject(testedWindow)
        check("main page gets the app's data", page.store === testedStore)
        var cover = testedWindow.cover.createObject(testedWindow)
        check("cover gets the app's data", cover.store === testedStore)

        var s = page.store
        if (!s.hasProfile) {
            console.log("SMOKE RUN 1")
            check("first run shows the welcome state", !page.hasProfile && !page.hasData)

            // Profile, opened the way the page's button opens it.
            var profile = make("pages/ProfileDialog.qml", { store: s })
            check("profile page starts empty", profile.cmText === "" && profile.ageText === "")
            check("can't save without a height", !profile.canAccept)
            profile.gender = "female"
            profile.ageText = "34"
            profile.heightUnit = "ftin"
            profile.ftText = "5"
            profile.inText = "9"
            profile.weightUnit = "lb"
            check("can save once height is in", profile.canAccept)
            profile.accepted()
            check("profile saved without error", s.lastError === "")
            check("main page moves on to 'add your first weight'", page.hasProfile && !page.hasData)

            // Weights, opened the way the page's button opens the dialog.
            var add = make("pages/AddEntryDialog.qml", { store: s })
            check("add weight starts in the profile's unit (lb)", add.unit === "lb")
            add.weightText = "181,5" // comma decimal, as a Finnish keyboard types it
            check("181,5 lb can be saved", add.canAccept)
            add.accepted()

            var add2 = make("pages/AddEntryDialog.qml", { store: s })
            add2.unit = "kg"
            add2.weightText = "76.5"
            add2.selectedDate = new Date(2026, 0, 15)
            add2.accepted()

            var junk = make("pages/AddEntryDialog.qml", { store: s })
            junk.weightText = "abc"
            check("junk weight can't be saved", !junk.canAccept)

            check("two weights stored", s.entries.length === 2)
            check("main page shows the data", page.hasData)
        } else {
            console.log("SMOKE RUN 2")
            check("profile survived the restart",
                  s.gender === "female" && s.age === 34 && s.heightUnit === "ftin" && s.weightUnit === "lb")
            check("height survived the restart (5 ft 9 in = 175.3 cm)", Math.abs(s.heightCm - 175.3) < 0.01)
            check("weights survived the restart", s.entries.length === 2)
            check("history is oldest first", s.entries.length === 2 && s.entries[0].date === "2026-01-15")
            check("181.5 lb stored as 82.3 kg",
                  s.entries.length === 2 && Math.abs(s.entries[1].weightKg - 82.327) < 0.01)

            // The profile page must open filled in, not reset.
            var again = make("pages/ProfileDialog.qml", { store: s })
            check("profile page shows the saved gender", again.gender === "female")
            check("profile page shows the saved age", again.ageText === "34")
            check("profile page shows the saved height",
                  again.heightUnit === "ftin" && again.ftText === "5" && again.inText === "9")
            check("profile page shows the saved unit", again.weightUnit === "lb")
            check("profile can be saved again unchanged", again.canAccept)

            noNaN("BMI", Bmi.formatBmi(s.currentBmi))
            noNaN("weight", Bmi.formatWeight(s.latest.weightKg, s.weightUnit))
            noNaN("height", Bmi.formatHeight(s.heightCm, s.heightUnit))
            noNaN("normal range", Bmi.formatRange(Bmi.healthyRange(s.heightCm), s.weightUnit))
            check("latest BMI is 26.8, overweight",
                  Bmi.formatBmi(s.currentBmi) === "26.8" && s.currentCategory.key === "over")

            check("delete works", s.removeEntry(s.entries[0].id) && s.entries.length === 1)

            // About and disclaimers, opened the way the menu opens it.
            var about = make("pages/AboutPage.qml", { store: s })
            check("about page opens", about !== null)
            check("made by Valatalo", about !== null && about.author === "Valatalo")
            check("no OpenRepos link until one is set", about !== null && about.openReposUrl === "")

            // The chart is built with the Window import it needs on Qt 5.6.
            var chart = make("components/BmiChart.qml", { entries: s.entries })
            check("chart loads with its background-repaint hooks",
                  chart !== null && chart.paintCount !== undefined && typeof chart.repaint === "function")

            // "Delete all my data" (last: it wipes what the checks above used).
            check("delete all data empties the profile and weights",
                  s.clearAll() && !s.hasProfile && s.entries.length === 0)
        }
        console.log("SMOKE DONE failures=" + failures)
    }
}
