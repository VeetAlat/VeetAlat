Name:       sailfishos-patch-statusbar
Summary:    StatusBar: a black bar with the time and status over the notch in apps
Version:    0.1.0
Release:    1
BuildArch:  noarch
License:    MIT
URL:        https://github.com/VeetAlat/VeetAlat
Source0:    %{name}-%{version}.tar.bz2

Requires:   patchmanager
Requires:   lipstick-jolla-home-qt5

%description
A Patchmanager patch for Sailfish OS phones with a notch. While an app is
open with the phone upright, a black bar covers the notch and shows the
time and the home screen's status icons (battery, profile, Bluetooth,
Wi-Fi, mobile signal), like the bar Android apps get.

The patch changes one line's worth of the home screen (AppLayer.qml): it
loads the bar from this package's own folder, so if the bar fails to load
on some Sailfish version, apps still work, just without it.

Apply it in Settings -> Patchmanager. Made by Valatalo.

%prep
%setup -q -n %{name}-%{version}

%build

%install
mkdir -p %{buildroot}%{_datadir}/patchmanager/patches/%{name}
cp patch/patch.json patch/unified_diff.patch %{buildroot}%{_datadir}/patchmanager/patches/%{name}/
mkdir -p %{buildroot}%{_datadir}/%{name}
cp qml/NotchStatusBar.qml %{buildroot}%{_datadir}/%{name}/

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
* Thu Nov 12 2026 Valatalo - 0.1.0-1
- First version: a black bar over the notch in apps, with the time and
  the status icons. Built against Sailfish OS 4.6's home screen.
