Name:       sailfishos-patch-statusbar
Summary:    StatusBar: a black bar with the time and status over the notch in apps
Version:    0.2.0
Release:    1
BuildArch:  noarch
License:    MIT
URL:        https://github.com/VeetAlat/VeetAlat
Source0:    %{name}-%{version}.tar.bz2

Requires:   patchmanager
Requires:   lipstick-jolla-home-qt5

%description
A Patchmanager patch for Sailfish OS phones with a notch. While an app is
open with the phone upright, a black bar covers the notch. Left of the
notch it shows the time and a compact battery (the percentage inside it);
right of it, the home screen's own status icons (Bluetooth, Wi-Fi, mobile
signal...), like the bar Android apps get.

The patch adds one Loader to the home screen (AppLayer.qml): it loads the
bar from this package's own folder, so if the bar fails to load on some
Sailfish version, apps still work, just without it.

Apply it in Settings -> Patchmanager. Made by Valatalo.

%prep
%setup -q -n %{name}-%{version}

%build

%install
mkdir -p %{buildroot}%{_datadir}/patchmanager/patches/%{name}
cp patch/patch.json patch/unified_diff.patch %{buildroot}%{_datadir}/patchmanager/patches/%{name}/
mkdir -p %{buildroot}%{_datadir}/%{name}
cp qml/*.qml %{buildroot}%{_datadir}/%{name}/

%preun
# Take the patch off before its files go.
if [ $1 -eq 0 ] && [ -x /usr/sbin/patchmanager ]; then
    /usr/sbin/patchmanager -u %{name} || true
fi

%files
%defattr(-,root,root,-)
%{_datadir}/patchmanager/patches/%{name}
%{_datadir}/%{name}

%changelog
* Thu Nov 12 2026 Valatalo - 0.2.0-1
- The bar from VeetPatched 0.3.0, as tested on the Jolla Phone: the clock
  and a compact battery left of the notch, the home screen's status icons
  right of it, no overlap. The battery's numbers come from the first
  source that works (MCE, Sailfish's battery indicator, the system
  settings).
- The diff only needs the file's last two lines to match, so it applies
  to Sailfish 4.6 and 5.2 alike.

* Thu Nov 12 2026 Valatalo - 0.1.0-1
- First version: a black bar over the notch in apps, with the time and
  the status icons. Built against Sailfish OS 4.6's home screen.
