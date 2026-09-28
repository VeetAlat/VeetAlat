#!/usr/bin/env python3
"""Minimal stand-in for ofono, just enough for nr-mode-helper.

One modem at /ril_0 with RadioSettings and NetworkRegistration. The
registration status comes from the file named by FAKE_OFONO_STATUS_FILE
(default "registered"), and every SetProperty call is appended to
FAKE_OFONO_LOG so tests can check what the helper did.
"""
import os

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

MODEM = "/ril_0"


class Manager(dbus.service.Object):
    @dbus.service.method("org.ofono.Manager", out_signature="a(oa{sv})")
    def GetModems(self):
        return [(dbus.ObjectPath(MODEM), {"Online": True})]


# dbus-python finds methods by walking the MRO for a matching name and
# interface, so each ofono interface lives in its own mixin.
class RadioSettings:
    pref = "nr"

    @dbus.service.method("org.ofono.RadioSettings", out_signature="a{sv}")
    def GetProperties(self):
        return {
            "TechnologyPreference": self.pref,
            "AvailableTechnologies": dbus.Array(
                ["gsm", "umts", "lte", "nr"], signature="s"),
        }

    @dbus.service.method("org.ofono.RadioSettings", in_signature="sv")
    def SetProperty(self, name, value):
        self.pref = str(value)
        with open(os.environ["FAKE_OFONO_LOG"], "a") as f:
            f.write(f"{name}={value}\n")


class NetworkRegistration:
    @dbus.service.method("org.ofono.NetworkRegistration",
                         out_signature="a{sv}")
    def GetProperties(self):
        try:
            with open(os.environ["FAKE_OFONO_STATUS_FILE"]) as f:
                status = f.read().strip()
        except (KeyError, OSError):
            status = "registered"
        return {"Status": status, "Technology": "nr"}


class Modem(dbus.service.Object, RadioSettings, NetworkRegistration):
    pass


def main():
    DBusGMainLoop(set_as_default=True)
    bus = dbus.bus.BusConnection(os.environ["DBUS_SYSTEM_BUS_ADDRESS"])
    name = dbus.service.BusName("org.ofono", bus)
    objects = [Manager(bus, "/"), Modem(bus, MODEM)]
    GLib.MainLoop().run()
    del name, objects


if __name__ == "__main__":
    main()
