import QtQuick 2.0
import "components"
import "js/bmi.js" as Bmi

// The history chart with sample data; "paints" counts its paints.
Rectangle {
    id: root
    width: 720; height: 420; color: "#16222c"
    property int paints: 0
    property var entries: {
        var kg = [88, 86.5, 84, 83, 80.2, 78, 76.6, 75]
        var list = []
        for (var i = 0; i < kg.length; i++) {
            list.push({ date: "2026-0" + (i + 1) + "-15", weightKg: kg[i], bmi: Bmi.bmi(kg[i], 175) })
        }
        return list
    }
    BmiChart {
        id: chart
        x: 24; y: 24; width: parent.width - 48
        entries: root.entries
        onPaintCountChanged: root.paints = paintCount
    }
}
