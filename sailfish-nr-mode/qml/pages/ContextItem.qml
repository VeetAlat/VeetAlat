import QtQuick 2.0
import Sailfish.Silica 1.0
import QOfono 0.2

// One data context (APN) with its settings and live state.
DetailItem {
    property alias contextPath: context.contextPath

    label: "APN " + (context.type || "")
    value: (context.accessPointName || "(empty)")
           + " · " + (context.protocol || "?")
           + " · " + (context.active ? "active" : "inactive")
           + (context.active && context.settings && context.settings.Address
              ? "\n" + context.settings.Address : "")

    OfonoContextConnection { id: context }
}
