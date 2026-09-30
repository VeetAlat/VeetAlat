import QtQuick 2.0
import Sailfish.Silica 1.0
import NeonRider 1.0

// Injected into a copy of the app by tests/sdk-smoke-test.sh (never
// shipped). The app runs without a window, on Sailfish's own Qt and
// Silica, with its real pages and game loop. Run 1 plays a game through
// the page's own buttons until it ends; run 2 (a restart) checks the best
// distance and bike colour were kept.
Item {
    id: smoke

    property var testedWindow
    property int failures: 0
    property int step: 0
    property var page
    property int waited: 0

    function check(name, ok) {
        console.log((ok ? "SMOKE PASS " : "SMOKE FAIL ") + name)
        if (!ok) failures++
    }
    function finish() {
        ticker.stop()
        console.log("SMOKE DONE failures=" + failures)
        Qt.quit()
    }

    // The first item under `item` for which test(item) is true.
    function find(item, test) {
        if (!item) return null
        if (test(item)) return item
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) {
            var found = find(kids[i], test)
            if (found) return found
        }
        return null
    }
    function button(text) {
        return find(page, function(i) {
            return i.hasOwnProperty("preferredWidth") && i.text === text && i.visible
        })
    }
    function label(text) {
        return find(page, function(i) {
            return i.hasOwnProperty("truncationMode") && i.text === text && i.visible
        })
    }

    Component.onCompleted: ticker.start()

    Timer {
        id: ticker
        interval: 100
        repeat: true
        onTriggered: {
            var stack = smoke.testedWindow.pageStack
            if (!smoke.page) {
                smoke.page = stack.currentPage
                if (!smoke.page) return
            }
            var p = smoke.page
            var bar = smoke.find(p, function(i) { return i.hasOwnProperty("buttonSize") })
            var tunnel = smoke.find(p, function(i) { return i.hasOwnProperty("game") })

            switch (smoke.step++) {
            case 0:
                var secondRun = gameEngine.best > 0
                console.log(secondRun ? "SMOKE RUN 2" : "SMOKE RUN 1")
                smoke.check("the tunnel draws the game", tunnel !== null && tunnel.game === gameEngine)
                smoke.check("starts on the start screen", gameEngine.state === Game.Ready && p.menuShown)
                smoke.check("title shown", smoke.label("NEON RIDER") !== null)
                smoke.check("three buttons", bar !== null)
                var cover = smoke.testedWindow.cover.createObject(smoke)
                smoke.check("cover builds", cover !== null)
                if (secondRun) {
                    smoke.check("best distance kept", smoke.label("Best " + gameEngine.best + " m") !== null)
                    smoke.check("bike colour kept", gameEngine.bikeColor === 0)
                    smoke.finish()
                    return
                }
                smoke.check("nothing saved yet", gameEngine.best === 0 && gameEngine.bikeColor === 1)
                var picker = smoke.find(p, function(i) { return i.hasOwnProperty("selected") })
                picker.picked(0)
                smoke.check("red bike chosen", gameEngine.bikeColor === 0 && picker.selected === 0)

                var about = stack.push(Qt.resolvedUrl("pages/AboutPage.qml"), {}, PageStackAction.Immediate)
                smoke.check("about page opens", about !== null && about.author === "Valatalo")
                smoke.check("no OpenRepos link until one is set", about.openReposUrl === "")
                stack.pop(null, PageStackAction.Immediate)

                bar.leftPressed()
                smoke.check("buttons do nothing before the ride", gameEngine.lane === 1)
                smoke.button("Play").clicked(null)
                smoke.check("Play starts the ride", gameEngine.state === Game.Running && p.playing && !p.menuShown)
                break
            case 3:
                smoke.check("the game loop runs", gameEngine.score > 0)
                bar.rightPressed()
                bar.rightPressed()
                smoke.check("right button moves right, up the wall", gameEngine.lane === 3)
                bar.leftPressed()
                smoke.check("left button moves left", gameEngine.lane === 2)
                bar.jumpPressed()
                var pause = smoke.find(p, function(i) { return i.hasOwnProperty("pressed") && i.visible && i.width === Theme.itemSizeLarge })
                pause.clicked(null)
                smoke.check("pause button pauses", gameEngine.paused && p.menuShown && smoke.label("PAUSED") !== null)
                smoke.paused = gameEngine.score
                break
            case 6:
                smoke.check("nothing moves while paused", gameEngine.score === smoke.paused)
                smoke.button("Continue").clicked(null)
                smoke.check("Continue carries on", gameEngine.state === Game.Running && !gameEngine.paused)
                break
            default:
                if (smoke.step < 8) break
                // Ride on without touching anything until the track ends it.
                if (gameEngine.state === Game.Running) {
                    if (++smoke.waited > 900) {
                        smoke.check("the ride ends", false)
                        smoke.finish()
                    }
                    smoke.step--
                    break
                }
                smoke.check("the ride ends", gameEngine.state === Game.Over)
                smoke.check("game over shown", smoke.label("GAME OVER") !== null
                            && smoke.label(gameEngine.deathReason) !== null)
                smoke.check("distance and new best", gameEngine.score > 30 && gameEngine.newBest
                            && gameEngine.best === gameEngine.score)
                smoke.check("Play again offered", smoke.button("Play again") !== null)
                smoke.finish()
            }
        }
    }

    property int paused: 0
}
