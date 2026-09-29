Name:       nr-mode
Summary:    Lock the modem to 5G NR standalone (NR only)
Version:    0.2.0
Release:    1
License:    MIT
URL:        https://github.com/VeetAlat/VeetAlat
Source0:    %{name}-%{version}.tar.bz2

Requires:   sailfishsilica-qt5 >= 0.10.9
Requires:   libqofono-qt5-declarative
Requires:   nemo-qml-plugin-configuration-qt5
Requires:   ofono-binder-plugin
Requires:   dbus
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  desktop-file-utils

%description
Adds an "NR only" switch, like Android's *#*#4636#*#* menu, for phones that
use ofono-binder-plugin. A small root helper makes ofono ask the modem for
5G NR only, which means standalone (SA) cells and nothing else.

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5
%make_build

%install
%qmake5_install
desktop-file-install --delete-original \
    --dir %{buildroot}%{_datadir}/applications \
    %{buildroot}%{_datadir}/applications/*.desktop

%post
systemd-tmpfiles --create /usr/lib/tmpfiles.d/nr-mode.conf || :
systemctl daemon-reload || :
systemctl enable --now nr-mode-apply.path || :

%preun
if [ $1 -eq 0 ]; then
    systemctl disable --now nr-mode-apply.path || :
    # Don't leave the phone stuck on NR only once the switch is gone.
    if [ -f /etc/ofono/binder.d/90-nr-mode.conf ]; then
        /usr/libexec/nr-mode/nr-mode-helper off || :
    fi
fi

%postun
systemctl daemon-reload || :

%files
%defattr(-,root,root,-)
%attr(2755,root,privileged) %{_bindir}/%{name}
%attr(0755,root,root) /usr/libexec/nr-mode/nr-mode-helper
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
/usr/lib/systemd/system/nr-mode-apply.path
/usr/lib/systemd/system/nr-mode-apply.service
/usr/lib/tmpfiles.d/nr-mode.conf
