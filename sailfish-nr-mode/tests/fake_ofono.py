#!/usr/bin/env python3
"""Minimal stand-in for ofono, just enough for nr-mode-helper.

One modem at /ril_0 with the interfaces the helper reads, one data context
and two cells (a serving NR cell and an LTE neighbour). The registration
status comes from the file named by FAKE_OFONO_STATUS_FILE (default
"registered"), and every SetProperty call is appended to FAKE_OFONO_LOG so
tests can check what the helper did.
"""
import os

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

MODEM = "/ril_0"
CONTEXT = MODEM + "/context1"
CELLS = {
    MODEM + "/cell_0": ("nr", True, {
        "mcc": dbus.Int32(244), "mnc": dbus.Int32(91), "pci": dbus.Int32(301),
        "nrarfcn": dbus.Int32(636666), "ssRsrp": dbus.Int32(95),
        "ssRsrq": dbus.Int32(11), "ssSinr": dbus.Int32(14),
        "nci": dbus.Int64(123456789)}),
    MODEM + "/cell_1": ("lte", False, {
        "mcc": dbus.Int32(244), "mnc": dbus.Int32(91), "pci": dbus.Int32(12),
        "earfcn": dbus.Int32(6300), "rsrp": dbus.Int32(101),
        "rsrq": dbus.Int32(9), "rssnr": dbus.Int32(125)}),
}


class Manager(dbus.service.Object):
    @dbus.service.method("org.ofono.Manager", out_signature="a(oa{sv})")
    def GetModems(self):
        return [(dbus.ObjectPath(MODEM), {"Online": True})]


# dbus-python finds methods by walking the MRO for a matching name and
# interface, so each ofono interface lives in its own mixin.
class ModemIface:
    @dbus.service.method("org.ofono.Modem", out_signature="a{sv}")
    def GetProperties(self):
        return {"Online": True, "Powered": True, "Model": "Fake 5G",
                "Interfaces": dbus.Array(["org.ofono.SimManager"],
                                         signature="s")}


class SimManager:
    @dbus.service.method("org.ofono.SimManager", out_signature="a{sv}")
    def GetProperties(self):
        return {"Present": True, "SubscriberIdentity": "244911234567890",
                "CardIdentifier": "8935891000012345678",
                "MobileCountryCode": "244", "MobileNetworkCode": "91",
                "ServiceProviderName": "Fake Telecom", "PinRequired": "none"}


def techs():
    """AvailableTechnologies, overridable via FAKE_OFONO_TECHS_FILE to
    mimic phones whose ofono config leaves NR out."""
    try:
        with open(os.environ["FAKE_OFONO_TECHS_FILE"]) as f:
            return f.read().split()
    except (KeyError, OSError):
        return ["gsm", "umts", "lte", "nr"]


class RadioSettings:
    pref = "nr"

    @dbus.service.method("org.ofono.RadioSettings", out_signature="a{sv}")
    def GetProperties(self):
        return {
            "TechnologyPreference": self.pref,
            "AvailableTechnologies": dbus.Array(techs(), signature="s"),
        }

    @dbus.service.method("org.ofono.RadioSettings", in_signature="sv")
    def SetProperty(self, name, value):
        if str(value) not in ("any",) + tuple(techs()):
            raise dbus.exceptions.DBusException(
                "org.ofono.Error.InvalidArguments")
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
        return {"Status": status, "Technology": "nr",
                "Name": "Fake Telecom", "Strength": dbus.Byte(62)}


class ConnectionManager:
    @dbus.service.method("org.ofono.ConnectionManager",
                         out_signature="a{sv}")
    def GetProperties(self):
        return {"Attached": True, "Bearer": "nr", "Powered": True,
                "RoamingAllowed": False}

    @dbus.service.method("org.ofono.ConnectionManager",
                         out_signature="a(oa{sv})")
    def GetContexts(self):
        return [(dbus.ObjectPath(CONTEXT), {
            "Active": True, "AccessPointName": "internet", "Type": "internet",
            "Protocol": "dual", "Password": "secret"})]


class CellInfo:
    @dbus.service.method("org.nemomobile.ofono.CellInfo", out_signature="ao")
    def GetCells(self):
        return [dbus.ObjectPath(p) for p in sorted(CELLS)]


class Modem(dbus.service.Object, ModemIface, SimManager, RadioSettings,
            NetworkRegistration, ConnectionManager, CellInfo):
    pass


class Cell(dbus.service.Object):
    def __init__(self, bus, path):
        super().__init__(bus, path)
        self.type, self.registered, self.props = CELLS[path]

    @dbus.service.method("org.nemomobile.ofono.Cell", out_signature="s")
    def GetType(self):
        return self.type

    @dbus.service.method("org.nemomobile.ofono.Cell", out_signature="b")
    def GetRegistered(self):
        return self.registered

    @dbus.service.method("org.nemomobile.ofono.Cell", out_signature="a{sv}")
    def GetProperties(self):
        return self.props


def main():
    DBusGMainLoop(set_as_default=True)
    bus = dbus.bus.BusConnection(os.environ["DBUS_SYSTEM_BUS_ADDRESS"])
    name = dbus.service.BusName("org.ofono", bus)
    objects = [Manager(bus, "/"), Modem(bus, MODEM)]
    objects += [Cell(bus, p) for p in CELLS]
    GLib.MainLoop().run()
    del name, objects


if __name__ == "__main__":
    main()
