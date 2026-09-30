import QtQuick 2.0
import QtMultimedia 5.0

// The game's sounds (made by tools/make-sounds.py): the bike's electric hum
// while riding, rising in pitch with speed, and a swoosh, jump, crash or
// fall when those happen.
Item {
    id: sounds

    // Hum while this is true.
    property bool riding: false
    // 0 at the starting speed, 1 at top speed: blends the low hum into the
    // high one.
    property real speed: 0

    SoundEffect {
        id: humLow
        source: "../sounds/hum-low.wav"
        loops: SoundEffect.Infinite
        volume: 0.4 * (1 - sounds.speed)
    }
    SoundEffect {
        id: humHigh
        source: "../sounds/hum-high.wav"
        loops: SoundEffect.Infinite
        volume: 0.4 * sounds.speed
    }

    // Two of each quick sound, taking turns, so quick presses overlap
    // instead of cutting each other off.
    property int turn: 0
    SoundEffect { id: swooshA; source: "../sounds/swoosh.wav"; volume: 0.55 }
    SoundEffect { id: swooshB; source: "../sounds/swoosh.wav"; volume: 0.55 }
    SoundEffect { id: jumpA; source: "../sounds/jump.wav"; volume: 0.65 }
    SoundEffect { id: jumpB; source: "../sounds/jump.wav"; volume: 0.65 }
    SoundEffect { id: crash; source: "../sounds/crash.wav"; volume: 0.9 }
    SoundEffect { id: fall; source: "../sounds/fall.wav"; volume: 0.8 }

    function playOne(a, b) {
        turn = 1 - turn
        if (turn) a.play(); else b.play()
    }

    onRidingChanged: {
        if (riding) {
            humLow.play()
            humHigh.play()
        } else {
            humLow.stop()
            humHigh.stop()
        }
    }

    Connections {
        target: gameEngine
        onMoved: sounds.playOne(swooshA, swooshB)
        onJumped: sounds.playOne(jumpA, jumpB)
        onCrashed: crash.play()
        onFell: fall.play()
    }
}
