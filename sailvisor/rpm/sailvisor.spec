Name:       sailvisor
Version:    0.1.0
Release:    1
Summary:    Virtual machines on the MediaTek GenieZone hypervisor
License:    BSD-3-Clause AND GPL-2.0-only
Requires:   python3-base
Requires:   pyotherside-qml-plugin-python3-qt5
Requires:   sailfishsilica-qt5
Requires:   libsailfishapp-launcher
AutoReqProv: no

# prebuilt, statically linked aarch64 binaries: no stripping, debuginfo or bytecompiling
%define debug_package %{nil}
%define __os_install_post %{nil}
%define _build_id_links none
# xz payload: readable by older rpm versions (Sailfish OS)
%define _binary_payload w6.xzdio

%description
Sailvisor creates, starts and stops virtual machines on Sailfish OS devices with a
MediaTek GenieZone hypervisor (/dev/gzvm), such as the 2026 Jolla Phone. It bundles
crosvm built with the GenieZone backend, a tiny test guest, a boot self-test,
diagnostics and detailed logging. Command line tool: sailvisor-cli.

Bundled: crosvm (BSD-3-Clause), an Ubuntu arm64 Linux kernel and busybox (GPL-2.0).

%install
cp -a %{stagedir}/. %{buildroot}/

%files
%defattr(-,root,root,-)
%attr(0755,root,root) /usr/bin/sailvisor-cli
%dir /usr/libexec/sailvisor
%attr(0755,root,root) /usr/libexec/sailvisor/crosvm
/usr/libexec/sailvisor/crosvm.commit
/usr/share/sailvisor
/usr/share/applications/sailvisor.desktop
/usr/share/icons/hicolor/86x86/apps/sailvisor.png
/usr/share/icons/hicolor/108x108/apps/sailvisor.png
/usr/share/icons/hicolor/128x128/apps/sailvisor.png
/usr/share/icons/hicolor/172x172/apps/sailvisor.png

%changelog
* Mon Oct 12 2026 Sailvisor <sailvisor@localhost> - 0.1.0-1
- First version: VM list/create/edit/delete, start/stop/force-kill, live console with input,
  VM and app logs, diagnostics, boot self-test, debug report, experimental ISO import.
